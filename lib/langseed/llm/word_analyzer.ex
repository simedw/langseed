defmodule Langseed.LLM.WordAnalyzer do
  @moduledoc """
  Analyzes Chinese words using LLM to extract pinyin, meaning,
  part of speech, and self-referential explanations.
  """

  alias Langseed.Language
  alias Langseed.LLM.Client
  alias Langseed.Utils.StringUtils
  alias Langseed.Vocabulary.Concept

  @max_retries 3

  @type analysis :: %{
          pinyin: String.t(),
          meaning: String.t(),
          part_of_speech: String.t(),
          explanations: [String.t()],
          explanation_quality: integer() | nil,
          desired_words: [String.t()]
        }

  @doc """
  Analyzes a Chinese word within its context sentence to extract
  pinyin, meaning, part of speech, and a self-referential explanation.

  The explanation will only use characters from the known_words set + emojis.

  Returns {:ok, analysis} or {:error, reason}
  """
  @spec analyze(integer() | nil, String.t(), String.t() | nil, MapSet.t()) ::
          {:ok, analysis()} | {:error, String.t()}
  def analyze(user_id, word, context_sentence \\ nil, known_words \\ MapSet.new()) do
    known_chars = Language.extract_chars(known_words)
    analyze_with_retry(user_id, word, context_sentence, known_chars, @max_retries, [])
  end

  @doc """
  Regenerates explanations for a word using only known vocabulary.
  Returns {:ok, [explanations]} or {:error, reason}
  """
  @spec regenerate_explanation(integer() | nil, Concept.t(), MapSet.t()) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def regenerate_explanation(user_id, concept, known_words) do
    known_chars = Language.extract_chars(known_words)
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")
    previous = Enum.join(concept.explanations || [], ", ")

    prompt = build_regenerate_prompt(concept, known_chars_list, previous)

    case call_llm(prompt, user_id, "regenerate_explanation") do
      {:ok, data} ->
        explanations =
          data
          |> Map.get("explanations", [])
          |> Enum.filter(&(is_binary(&1) and Language.find_unknown_chars(&1, known_chars) == []))
          |> Enum.take(3)

        if Enum.empty?(explanations) do
          {:ok, ["🤔💭 #{concept.word}"]}
        else
          {:ok, explanations}
        end

      {:error, _} ->
        {:ok, ["🤔💭 #{concept.word}"]}
    end
  end

  # Private implementation

  defp analyze_with_retry(_user_id, _word, _context, _known_chars, 0, illegal_chars) do
    {:error,
     "Failed after #{@max_retries} retries. Could not avoid characters: #{Enum.join(illegal_chars, ", ")}"}
  end

  defp analyze_with_retry(
         user_id,
         word,
         context_sentence,
         known_chars,
         retries_left,
         previous_illegal
       ) do
    prompt = build_analyze_prompt(word, context_sentence, known_chars, previous_illegal)

    with {:ok, data} <- call_llm(prompt, user_id, "analyze_word"),
         {:ok, analysis} <- parse_analysis(data) do
      validate_and_filter_explanations(
        analysis,
        known_chars,
        user_id,
        word,
        context_sentence,
        retries_left
      )
    end
  end

  defp validate_and_filter_explanations(
         analysis,
         known_chars,
         user_id,
         word,
         context_sentence,
         retries_left
       ) do
    {valid_explanations, all_illegal} =
      Enum.reduce(analysis.explanations, {[], []}, fn explanation, {valid, illegal_acc} ->
        case Language.find_unknown_chars(explanation, known_chars) do
          [] -> {[explanation | valid], illegal_acc}
          illegal -> {valid, illegal_acc ++ illegal}
        end
      end)

    valid_explanations = Enum.reverse(valid_explanations)
    all_illegal = Enum.uniq(all_illegal)

    cond do
      length(valid_explanations) == length(analysis.explanations) ->
        {:ok, analysis}

      not Enum.empty?(valid_explanations) ->
        {:ok, %{analysis | explanations: valid_explanations}}

      retries_left > 1 ->
        analyze_with_retry(
          user_id,
          word,
          context_sentence,
          known_chars,
          retries_left - 1,
          all_illegal
        )

      true ->
        {:error,
         "Failed after #{@max_retries} retries. Could not avoid characters: #{Enum.join(all_illegal, ", ")}"}
    end
  end

  defp call_llm(prompt, user_id, query_type) do
    prompt
    |> Client.generate()
    |> Client.track_usage(user_id, query_type)
    |> Client.parse_json()
  end

  defp parse_analysis(%{"pinyin" => pinyin, "meaning" => meaning, "part_of_speech" => pos} = data) do
    explanations =
      case {Map.get(data, "explanations"), Map.get(data, "explanation")} do
        {list, _} when is_list(list) -> list |> Enum.filter(&is_binary/1) |> Enum.take(5)
        {_, str} when is_binary(str) and str != "" -> [str]
        _ -> []
      end

    {:ok,
     %{
       pinyin: pinyin,
       meaning: meaning,
       part_of_speech: normalize_part_of_speech(pos),
       explanations: explanations,
       explanation_quality: data |> Map.get("explanation_quality") |> normalize_quality(),
       desired_words: data |> Map.get("desired_words", []) |> normalize_desired_words()
     }}
  end

  defp parse_analysis(_), do: {:error, "Invalid response format"}

  defp normalize_quality(nil), do: nil
  defp normalize_quality(q) when is_integer(q) and q >= 1 and q <= 5, do: q
  defp normalize_quality(q) when is_integer(q) and q < 1, do: 1
  defp normalize_quality(q) when is_integer(q) and q > 5, do: 5
  defp normalize_quality(_), do: nil

  defp normalize_desired_words(nil), do: []

  defp normalize_desired_words(words) when is_list(words) do
    words
    |> Enum.filter(&is_binary/1)
    |> Enum.take(5)
  end

  defp normalize_desired_words(_), do: []

  defp normalize_part_of_speech(pos) do
    normalized =
      pos
      |> String.downcase()
      |> String.replace(" ", "_")

    if normalized in ~w(noun verb adjective adverb pronoun preposition conjunction particle numeral measure_word interjection) do
      normalized
    else
      "other"
    end
  end

  # Prompt builders

  defp build_analyze_prompt(word, context_sentence, known_chars, previous_illegal) do
    safe_word = StringUtils.ensure_valid_utf8(word)
    safe_sentence = StringUtils.ensure_valid_utf8(context_sentence)

    context_part =
      if safe_sentence != "" do
        "The word appears in this sentence: \"#{safe_sentence}\"\n"
      else
        ""
      end

    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")
    retry_feedback = build_retry_feedback(previous_illegal)

    """
    Analyze this Chinese word: "#{safe_word}"
    #{context_part}
    Respond ONLY with a JSON object in this exact format (no markdown, no code blocks):
    {
      "pinyin": "pinyin with tone marks",
      "meaning": "English meaning",
      "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, particle, numeral, measure_word, interjection, other",
      "explanations": ["explanation1", "explanation2", "explanation3"],
      "explanation_quality": 1-5,
      "desired_words": ["word1", "word2"]
    }

    CRITICAL RULES for the explanations field:
    - Provide 2-3 DIFFERENT explanations using different approaches:
      1. A short example sentence showing usage (use ____ for the word's position)
      2. An emoji-based visual hint
      3. A simple contextual phrase if possible
    - Each explanation should help understand the word from a DIFFERENT angle
    - ABSOLUTELY NO ENGLISH - not even single letters or quoted words
    - DO NOT break down the word into its component characters
    - The explanations MUST use ONLY these Chinese characters: #{known_chars_list}
    - You can use emojis freely
    - You can use numbers, punctuation, and spaces
    - Use ____ to show where the word fits in example sentences
    - Keep each explanation SHORT

    GOOD examples for 所以 (therefore): ["我 很 累，____ 我 要 休息", "1️⃣ ➡️ 2️⃣", "A，____ B"]
    GOOD examples for 好: ["👍😊", "很 ____！", "我 ____ 吃"]
    BAD examples: "你 是 you", "'hello'", "A is B"

    EXPLANATION_QUALITY (1-5):
    - 5: Perfect explanations using available characters
    - 4: Good, captures the meaning well
    - 3: Adequate, could be clearer
    - 2: Limited, mostly emojis
    - 1: Very poor

    DESIRED_WORDS: List 0-5 Chinese words that would help write better explanations.
    #{retry_feedback}
    """
  end

  defp build_regenerate_prompt(concept, known_chars_list, previous) do
    """
    Create NEW, DIFFERENT explanations for the Chinese word "#{concept.word}" (#{concept.meaning}).

    Previous explanations were: "#{previous}"
    Please create DIFFERENT explanations using different approaches.

    RULES:
    - Provide 2-3 DIFFERENT explanations:
      1. A short example sentence (use ____ for where the word goes)
      2. An emoji-based visual hint
      3. A contextual phrase if possible
    - Use ONLY these Chinese characters: #{known_chars_list}
    - You can use emojis freely
    - NO ENGLISH at all
    - Keep each short and visual
    - Try different angles than the previous explanations

    Respond ONLY with JSON (no markdown):
    {"explanations": ["explanation1", "explanation2", "explanation3"]}
    """
  end

  defp build_retry_feedback([]), do: ""

  defp build_retry_feedback(previous_illegal) do
    has_english_error = "[英文]" in previous_illegal
    illegal_chars = Enum.reject(previous_illegal, &(&1 == "[英文]"))

    english_warning =
      if has_english_error, do: "You used ENGLISH letters which is FORBIDDEN. ", else: ""

    char_warning =
      if Enum.empty?(illegal_chars),
        do: "",
        else: "You used these FORBIDDEN characters: #{Enum.join(illegal_chars, " ")}. "

    """

    ⚠️ RETRY: #{english_warning}#{char_warning}Use ONLY allowed Chinese characters or emojis. NO ENGLISH AT ALL.
    """
  end
end

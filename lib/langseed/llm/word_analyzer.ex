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
  Analyzes a word within its context sentence to extract
  pronunciation (pinyin for Chinese), meaning, part of speech, and explanations.

  The explanation will only use words from the known_words set + emojis.

  Returns {:ok, analysis} or {:error, reason}
  """
  @spec analyze(integer() | nil, String.t(), String.t() | nil, MapSet.t(), String.t()) ::
          {:ok, analysis()} | {:error, String.t()}
  def analyze(
        user_id,
        word,
        context_sentence \\ nil,
        known_words \\ MapSet.new(),
        language \\ "zh"
      ) do
    # Include the word being analyzed in allowed words
    allowed_words = MapSet.put(known_words, word)

    analyze_with_retry(
      user_id,
      word,
      context_sentence,
      known_words,
      allowed_words,
      language,
      @max_retries,
      []
    )
  end

  @doc """
  Regenerates explanations for a word using only known vocabulary.
  Returns {:ok, [explanations]} or {:error, reason}
  """
  @spec regenerate_explanation(integer() | nil, Concept.t(), MapSet.t()) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def regenerate_explanation(user_id, concept, known_words) do
    # Include the concept word in allowed words
    allowed_words = MapSet.put(known_words, concept.word)
    known_words_sample = known_words |> MapSet.to_list() |> Enum.take(50) |> Enum.join(" ")
    previous = Enum.join(concept.explanations || [], ", ")

    prompt = build_regenerate_prompt(concept, known_words_sample, previous)

    case call_llm(prompt, user_id, "regenerate_explanation") do
      {:ok, data} ->
        explanations =
          data
          |> Map.get("explanations", [])
          |> Enum.filter(
            &(is_binary(&1) and Language.find_unknown_words(&1, allowed_words) == [])
          )
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

  defp analyze_with_retry(
         _user_id,
         _word,
         _context,
         _known_words,
         _allowed_words,
         _language,
         0,
         illegal_words
       ) do
    {:error,
     "Failed after #{@max_retries} retries. Could not avoid words: #{Enum.join(illegal_words, ", ")}"}
  end

  defp analyze_with_retry(
         user_id,
         word,
         context_sentence,
         known_words,
         allowed_words,
         language,
         retries_left,
         previous_illegal
       ) do
    prompt = build_analyze_prompt(word, context_sentence, known_words, previous_illegal, language)

    with {:ok, data} <- call_llm(prompt, user_id, "analyze_word"),
         {:ok, analysis} <- parse_analysis(data, language) do
      validate_and_filter_explanations(
        analysis,
        allowed_words,
        user_id,
        word,
        context_sentence,
        known_words,
        language,
        retries_left
      )
    end
  end

  defp validate_and_filter_explanations(
         analysis,
         allowed_words,
         user_id,
         word,
         context_sentence,
         known_words,
         language,
         retries_left
       ) do
    {valid_explanations, all_illegal} =
      Enum.reduce(analysis.explanations, {[], []}, fn explanation, {valid, illegal_acc} ->
        case Language.find_unknown_words(explanation, allowed_words, language) do
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
          known_words,
          allowed_words,
          language,
          retries_left - 1,
          all_illegal
        )

      true ->
        {:error,
         "Failed after #{@max_retries} retries. Could not avoid words: #{Enum.join(all_illegal, ", ")}"}
    end
  end

  defp call_llm(prompt, user_id, query_type) do
    prompt
    |> Client.generate()
    |> Client.track_usage(user_id, query_type)
    |> Client.parse_json()
  end

  defp parse_analysis(%{"meaning" => meaning, "part_of_speech" => pos} = data, language) do
    explanations =
      case {Map.get(data, "explanations"), Map.get(data, "explanation")} do
        {list, _} when is_list(list) -> list |> Enum.filter(&is_binary/1) |> Enum.take(5)
        {_, str} when is_binary(str) and str != "" -> [str]
        _ -> []
      end

    # Pinyin only for Chinese
    pinyin = if language == "zh", do: Map.get(data, "pinyin", ""), else: ""

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

  defp parse_analysis(_, _language), do: {:error, "Invalid response format"}

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

  defp build_analyze_prompt(word, context_sentence, known_words, previous_illegal, language) do
    safe_word = StringUtils.ensure_valid_utf8(word)
    safe_sentence = StringUtils.ensure_valid_utf8(context_sentence)

    context_part =
      if safe_sentence != "" do
        "The word appears in this sentence: \"#{safe_sentence}\"\n"
      else
        ""
      end

    known_words_sample = known_words |> MapSet.to_list() |> Enum.take(50) |> Enum.join(" ")
    retry_feedback = build_retry_feedback(previous_illegal)

    language_name = language_name(language)
    target_language = target_explanation_language(language)

    # Chinese needs pinyin, others don't
    json_format =
      if language == "zh" do
        """
        {
          "pinyin": "pinyin with tone marks",
          "meaning": "English meaning",
          "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, particle, numeral, measure_word, interjection, other",
          "explanations": ["explanation1", "explanation2", "explanation3"],
          "explanation_quality": 1-5,
          "desired_words": ["word1", "word2"]
        }
        """
      else
        """
        {
          "meaning": "English meaning",
          "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, particle, numeral, measure_word, interjection, other",
          "explanations": ["explanation1", "explanation2", "explanation3"],
          "explanation_quality": 1-5,
          "desired_words": ["word1", "word2"]
        }
        """
      end

    """
    Analyze this #{language_name} word: "#{safe_word}"
    #{context_part}
    Respond ONLY with a JSON object in this exact format (no markdown, no code blocks):
    #{json_format}

    CRITICAL RULES for the explanations field:
    - Provide 2-3 DIFFERENT explanations using different approaches:
      1. A short example sentence showing usage in #{language_name} (use ____ for the word's position)
      2. An emoji-based visual hint
      3. A simple contextual phrase if possible
    - Each explanation should help understand the word from a DIFFERENT angle
    - Write explanations in #{target_language}
    - Use ONLY #{language_name} words the learner knows. Known words include: #{known_words_sample}
    - You can also use: #{safe_word}
    - You can use emojis freely
    - You can use numbers, punctuation, and spaces
    - Use ____ to show where the word fits in example sentences
    - Keep each explanation SHORT

    EXPLANATION_QUALITY (1-5):
    - 5: Perfect explanations using available words
    - 4: Good, captures the meaning well
    - 3: Adequate, could be clearer
    - 2: Limited, mostly emojis
    - 1: Very poor

    DESIRED_WORDS: List 0-5 #{language_name} words that would help write better explanations.
    These must be #{language_name} words, not English or other languages.
    #{retry_feedback}
    """
  end

  defp language_name("zh"), do: "Chinese"
  defp language_name("sv"), do: "Swedish"
  defp language_name("en"), do: "English"
  defp language_name(_), do: "the target language"

  defp target_explanation_language("zh"), do: "Chinese (no English)"
  defp target_explanation_language("sv"), do: "Swedish (no English)"
  defp target_explanation_language("en"), do: "simple English"
  defp target_explanation_language(_), do: "the target language"

  defp build_regenerate_prompt(concept, known_words_sample, previous) do
    """
    Create NEW, DIFFERENT explanations for the Chinese word "#{concept.word}" (#{concept.meaning}).

    Previous explanations were: "#{previous}"
    Please create DIFFERENT explanations using different approaches.

    RULES:
    - Provide 2-3 DIFFERENT explanations:
      1. A short example sentence (use ____ for where the word goes)
      2. An emoji-based visual hint
      3. A contextual phrase if possible
    - Use ONLY words the learner knows. Known words include: #{known_words_sample}
    - You can also use: #{concept.word}
    - IMPORTANT: Do NOT combine characters into words the learner doesn't know!
      For example, if they know 学 and 生 separately, do NOT use 学生 unless 学生 is in their vocabulary.
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
    illegal_words = Enum.reject(previous_illegal, &(&1 == "[英文]"))

    english_warning =
      if has_english_error, do: "You used ENGLISH letters which is FORBIDDEN. ", else: ""

    word_warning =
      if Enum.empty?(illegal_words),
        do: "",
        else:
          "You used these UNKNOWN WORDS: #{Enum.join(illegal_words, ", ")}. The learner does not know these words! "

    """

    ⚠️ RETRY: #{english_warning}#{word_warning}Use ONLY words from the learner's vocabulary. Do NOT combine characters into unknown words!
    """
  end
end

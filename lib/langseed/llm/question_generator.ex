defmodule Langseed.LLM.QuestionGenerator do
  @moduledoc """
  Generates practice questions (yes/no and fill-in-the-blank) using LLM.
  """

  alias Langseed.Language
  alias Langseed.LLM.Client
  alias Langseed.Vocabulary.Concept

  @max_retries 3

  @type yes_no_result :: %{
          question: String.t(),
          answer: boolean(),
          explanation: String.t()
        }

  @type fill_blank_result :: %{
          sentence: String.t(),
          options: [String.t()],
          correct_index: integer()
        }

  @doc """
  Generates a Yes/No question about the target word using only known vocabulary.
  Returns {:ok, %{question: ..., answer: true/false, explanation: ...}} or {:error, reason}
  """
  @spec generate_yes_no(integer() | nil, Concept.t(), MapSet.t()) ::
          {:ok, yes_no_result()} | {:error, String.t()}
  def generate_yes_no(user_id, concept, known_words) do
    known_chars = Language.extract_chars(known_words)
    target_chars = concept.word |> String.graphemes() |> MapSet.new()
    allowed_chars = MapSet.union(known_chars, target_chars)

    generate_yes_no_with_retry(user_id, concept, known_chars, allowed_chars, [], @max_retries)
  end

  @doc """
  Generates a fill-in-the-blank question with multiple choice options.
  Returns {:ok, %{sentence: ..., options: [...], correct_index: 0-3}} or {:error, reason}
  """
  @spec generate_fill_blank(integer() | nil, Concept.t(), MapSet.t(), [Concept.t()]) ::
          {:ok, fill_blank_result()} | {:error, String.t()}
  def generate_fill_blank(user_id, concept, known_words, distractor_words) do
    known_chars = Language.extract_chars(known_words)
    target_chars = concept.word |> String.graphemes() |> MapSet.new()

    distractor_chars =
      distractor_words
      |> Enum.flat_map(&String.graphemes(&1.word))
      |> MapSet.new()

    allowed_chars =
      known_chars
      |> MapSet.union(target_chars)
      |> MapSet.union(distractor_chars)

    generate_fill_blank_with_retry(
      user_id,
      concept,
      known_chars,
      allowed_chars,
      distractor_words,
      [],
      @max_retries
    )
  end

  # Yes/No question generation

  defp generate_yes_no_with_retry(
         _user_id,
         _concept,
         _known_chars,
         _allowed_chars,
         _previous_illegal,
         0
       ) do
    {:error, "Failed to generate valid question after #{@max_retries} attempts"}
  end

  defp generate_yes_no_with_retry(
         user_id,
         concept,
         known_chars,
         allowed_chars,
         previous_illegal,
         attempts
       ) do
    prompt = build_yes_no_prompt(concept, known_chars, previous_illegal)

    with {:ok, data} <- call_llm(prompt, user_id, "yes_no_question"),
         {:ok, result} <- parse_yes_no(data),
         :ok <- validate_chars(result.question, allowed_chars) do
      {:ok, result}
    else
      {:invalid_chars, illegal} ->
        generate_yes_no_with_retry(
          user_id,
          concept,
          known_chars,
          allowed_chars,
          illegal,
          attempts - 1
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_yes_no_prompt(concept, known_chars, previous_illegal) do
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")
    retry_feedback = build_retry_feedback(previous_illegal)

    """
    Generate a Yes/No question in Chinese to test understanding of the word "#{concept.word}" (#{concept.meaning}).
    #{retry_feedback}
    RULES:
    - The question must be answerable with YES (是/对) or NO (不是/不对)
    - Use ONLY these Chinese characters: #{known_chars_list}
    - You can also use: #{concept.word}
    - Use emojis if helpful
    - The question should test if the learner understands the MEANING of the word
    - Make the question clear and unambiguous
    - DO NOT use any Chinese character not in the allowed list above!

    Respond ONLY with JSON (no markdown):
    {"question": "Chinese question here", "answer": true or false, "explanation": "brief Chinese explanation of why"}

    Example for 晚上 (night):
    {"question": "太阳 在 晚上 出来 吗？", "answer": false, "explanation": "太阳 在 白天 出来，不是 晚上"}
    """
  end

  defp parse_yes_no(%{"question" => question, "answer" => answer} = data) do
    {:ok,
     %{
       question: question,
       answer: answer == true,
       explanation: Map.get(data, "explanation", "")
     }}
  end

  defp parse_yes_no(_), do: {:error, "Invalid yes/no question format"}

  # Fill-in-the-blank question generation

  defp generate_fill_blank_with_retry(
         _user_id,
         _concept,
         _known_chars,
         _allowed_chars,
         _distractors,
         _previous_illegal,
         0
       ) do
    {:error, "Failed to generate valid fill-blank question after #{@max_retries} attempts"}
  end

  defp generate_fill_blank_with_retry(
         user_id,
         concept,
         known_chars,
         allowed_chars,
         distractor_words,
         previous_illegal,
         attempts
       ) do
    prompt = build_fill_blank_prompt(concept, known_chars, distractor_words, previous_illegal)

    with {:ok, data} <- call_llm(prompt, user_id, "fill_blank_question"),
         {:ok, result} <- parse_fill_blank(data),
         sentence_text = String.replace(result.sentence, "____", ""),
         :ok <- validate_chars(sentence_text, allowed_chars) do
      {:ok, result}
    else
      {:invalid_chars, illegal} ->
        generate_fill_blank_with_retry(
          user_id,
          concept,
          known_chars,
          allowed_chars,
          distractor_words,
          illegal,
          attempts - 1
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_fill_blank_prompt(concept, known_chars, distractor_words, previous_illegal) do
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")
    distractors = distractor_words |> Enum.take(3) |> Enum.map(& &1.word) |> Enum.join(", ")
    retry_feedback = build_retry_feedback(previous_illegal)

    """
    Generate a fill-in-the-blank sentence in Chinese to test the word "#{concept.word}" (#{concept.meaning}).
    #{retry_feedback}
    RULES:
    - Create a sentence where "#{concept.word}" fits naturally in the blank
    - Use ONLY these Chinese characters (plus the blank): #{known_chars_list}
    - Mark the blank with ____
    - The context should make the correct answer clear
    - DO NOT use any Chinese character not in the allowed list above!

    The correct answer is: #{concept.word}
    Distractor options (wrong answers): #{distractors}

    Respond ONLY with JSON (no markdown):
    {"sentence": "我 喜欢 ____ 书", "options": ["#{concept.word}", "option2", "option3", "option4"], "correct_index": 0}

    IMPORTANT: Shuffle the options randomly, correct_index should match where #{concept.word} ends up (0-3).
    """
  end

  defp parse_fill_blank(%{"sentence" => sentence, "options" => options, "correct_index" => idx})
       when is_list(options) and is_integer(idx) do
    {:ok,
     %{
       sentence: sentence,
       options: options,
       correct_index: idx
     }}
  end

  defp parse_fill_blank(_), do: {:error, "Invalid fill-blank question format"}

  # Shared helpers

  defp call_llm(prompt, user_id, query_type) do
    prompt
    |> Client.generate()
    |> Client.track_usage(user_id, query_type)
    |> Client.parse_json()
  end

  defp validate_chars(text, allowed_chars) do
    case Language.find_unknown_chars(text, allowed_chars) do
      [] -> :ok
      illegal -> {:invalid_chars, illegal}
    end
  end

  defp build_retry_feedback([]), do: ""

  defp build_retry_feedback(previous_illegal) do
    has_english_error = "[英文]" in previous_illegal
    illegal_chars = Enum.reject(previous_illegal, &(&1 == "[英文]"))

    english_warning =
      if has_english_error do
        "You used ENGLISH letters which is FORBIDDEN. "
      else
        ""
      end

    char_warning =
      if Enum.empty?(illegal_chars) do
        ""
      else
        "You used these FORBIDDEN characters: #{Enum.join(illegal_chars, " ")}. "
      end

    """

    ⚠️ RETRY: #{english_warning}#{char_warning}Use ONLY allowed Chinese characters. NO unknown characters!
    """
  end
end

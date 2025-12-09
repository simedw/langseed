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
  @spec generate_yes_no(integer() | nil, Concept.t(), MapSet.t(), String.t()) ::
          {:ok, yes_no_result()} | {:error, String.t()}
  def generate_yes_no(user_id, concept, known_words, language \\ "zh") do
    # Include the target word in allowed words
    allowed_words = MapSet.put(known_words, concept.word)

    generate_yes_no_with_retry(user_id, concept, known_words, allowed_words, language, [], @max_retries)
  end

  @doc """
  Generates a fill-in-the-blank question with multiple choice options.
  Returns {:ok, %{sentence: ..., options: [...], correct_index: 0-3}} or {:error, reason}
  """
  @spec generate_fill_blank(integer() | nil, Concept.t(), MapSet.t(), [Concept.t()], String.t()) ::
          {:ok, fill_blank_result()} | {:error, String.t()}
  def generate_fill_blank(user_id, concept, known_words, distractor_words, language \\ "zh") do
    # Include target word and distractor words in allowed words
    distractor_word_set = distractor_words |> Enum.map(& &1.word) |> MapSet.new()

    allowed_words =
      known_words
      |> MapSet.put(concept.word)
      |> MapSet.union(distractor_word_set)

    generate_fill_blank_with_retry(
      user_id,
      concept,
      known_words,
      allowed_words,
      distractor_words,
      language,
      [],
      @max_retries
    )
  end

  # Yes/No question generation

  defp generate_yes_no_with_retry(
         _user_id,
         _concept,
         _known_words,
         _allowed_words,
         _language,
         _previous_illegal,
         0
       ) do
    {:error, "Failed to generate valid question after #{@max_retries} attempts"}
  end

  defp generate_yes_no_with_retry(
         user_id,
         concept,
         known_words,
         allowed_words,
         language,
         previous_illegal,
         attempts
       ) do
    prompt = build_yes_no_prompt(concept, known_words, previous_illegal, language)

    with {:ok, data} <- call_llm(prompt, user_id, "yes_no_question"),
         {:ok, result} <- parse_yes_no(data),
         :ok <- validate_words(result.question, allowed_words, language) do
      {:ok, result}
    else
      {:invalid_words, illegal} ->
        generate_yes_no_with_retry(
          user_id,
          concept,
          known_words,
          allowed_words,
          language,
          illegal,
          attempts - 1
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_yes_no_prompt(concept, known_words, previous_illegal, language) do
    # Show a sample of known words (not all, to keep prompt reasonable)
    known_words_sample =
      known_words
      |> MapSet.to_list()
      |> Enum.take(50)
      |> Enum.join(" ")

    retry_feedback = build_retry_feedback(previous_illegal)
    language_name = language_name(language)

    """
    Generate a Yes/No question in #{language_name} to test understanding of the word "#{concept.word}" (#{concept.meaning}).
    #{retry_feedback}
    RULES:
    - The question must be answerable with YES or NO
    - Write the question in #{language_name}
    - Use ONLY #{language_name} words the learner knows. Known words include: #{known_words_sample}
    - You can also use: #{concept.word}
    - Use emojis if helpful
    - The question should test if the learner understands the MEANING of the word
    - Make the question clear and unambiguous

    Respond ONLY with JSON (no markdown):
    {"question": "#{language_name} question here", "answer": true or false, "explanation": "brief #{language_name} explanation of why"}
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
         _known_words,
         _allowed_words,
         _distractors,
         _language,
         _previous_illegal,
         0
       ) do
    {:error, "Failed to generate valid fill-blank question after #{@max_retries} attempts"}
  end

  defp generate_fill_blank_with_retry(
         user_id,
         concept,
         known_words,
         allowed_words,
         distractor_words,
         language,
         previous_illegal,
         attempts
       ) do
    prompt = build_fill_blank_prompt(concept, known_words, distractor_words, previous_illegal, language)

    with {:ok, data} <- call_llm(prompt, user_id, "fill_blank_question"),
         {:ok, result} <- parse_fill_blank(data),
         sentence_text = String.replace(result.sentence, "____", ""),
         :ok <- validate_words(sentence_text, allowed_words, language) do
      {:ok, result}
    else
      {:invalid_words, illegal} ->
        generate_fill_blank_with_retry(
          user_id,
          concept,
          known_words,
          allowed_words,
          distractor_words,
          language,
          illegal,
          attempts - 1
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_fill_blank_prompt(concept, known_words, distractor_words, previous_illegal, language) do
    # Show a sample of known words (not all, to keep prompt reasonable)
    known_words_sample =
      known_words
      |> MapSet.to_list()
      |> Enum.take(50)
      |> Enum.join(" ")

    distractors = distractor_words |> Enum.take(3) |> Enum.map(& &1.word) |> Enum.join(", ")
    retry_feedback = build_retry_feedback(previous_illegal)
    language_name = language_name(language)

    """
    Generate a fill-in-the-blank sentence in #{language_name} to test the word "#{concept.word}" (#{concept.meaning}).
    #{retry_feedback}
    RULES:
    - Create a #{language_name} sentence where "#{concept.word}" fits naturally in the blank
    - Use ONLY #{language_name} words the learner knows. Known words include: #{known_words_sample}
    - Mark the blank with ____
    - The context should make the correct answer clear

    The correct answer is: #{concept.word}
    Distractor options (wrong answers): #{distractors}

    Respond ONLY with JSON (no markdown):
    {"sentence": "#{language_name} sentence with ____ blank", "options": ["#{concept.word}", "option2", "option3", "option4"], "correct_index": 0}

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

  defp validate_words(text, allowed_words, language) do
    case Language.find_unknown_words(text, allowed_words, language) do
      [] -> :ok
      illegal -> {:invalid_words, illegal}
    end
  end

  defp language_name("zh"), do: "Chinese"
  defp language_name("sv"), do: "Swedish"
  defp language_name("en"), do: "English"
  defp language_name(_), do: "the target language"

  defp build_retry_feedback([]), do: ""

  defp build_retry_feedback(previous_illegal) do
    illegal_words = previous_illegal

    word_warning =
      if Enum.empty?(illegal_words) do
        ""
      else
        "You used these UNKNOWN WORDS: #{Enum.join(illegal_words, ", ")}. The learner does not know these words! "
      end

    """

    ⚠️ RETRY: #{word_warning}Use ONLY words from the learner's vocabulary.
    """
  end
end

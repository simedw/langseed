defmodule Langseed.LLM.SentenceEvaluator do
  @moduledoc """
  Evaluates user-written sentences using LLM.
  """

  alias Langseed.LLM.Client
  alias Langseed.Vocabulary.Concept

  @type evaluation_result :: %{
          correct: boolean(),
          feedback: String.t(),
          improved: String.t() | nil
        }

  @doc """
  Evaluates a sentence written by the user using the target word.
  Returns {:ok, %{correct: true/false, feedback: "...", improved: "..."}} or {:error, reason}
  """
  @spec evaluate(integer() | nil, Concept.t(), String.t(), MapSet.t(), String.t()) ::
          {:ok, evaluation_result()} | {:error, String.t()}
  def evaluate(user_id, concept, user_sentence, known_words, language \\ "zh") do
    known_words_list = known_words |> MapSet.to_list() |> Enum.take(50) |> Enum.join(" ")

    prompt = build_prompt(concept, user_sentence, known_words_list, language)

    case call_llm(prompt, user_id, "evaluate_sentence") do
      {:ok, data} -> parse_evaluation(data)
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_prompt(concept, user_sentence, known_words_list, language) do
    language_name = language_name(language)

    """
    You are evaluating a #{language_name} sentence written by a language learner.
    IMPORTANT: Write ALL feedback in #{language_name} using ONLY words the learner knows.

    Target word they should use: "#{concept.word}" (meaning: #{concept.meaning})
    Learner's sentence: "#{user_sentence}"

    Words the learner knows (use only these in your feedback): #{known_words_list}

    Check if:
    1. The sentence uses "#{concept.word}" correctly
    2. The sentence is grammatically correct in #{language_name}
    3. The sentence makes sense

    Respond ONLY with JSON (no markdown):
    {"correct": true/false, "feedback": "your #{language_name} feedback here using only known words", "improved": "improved #{language_name} sentence if needed, or null"}

    Be encouraging! Write your feedback ONLY in #{language_name} using ONLY words from the learner's vocabulary.
    """
  end

  defp language_name("zh"), do: "Chinese"
  defp language_name("sv"), do: "Swedish"
  defp language_name("en"), do: "English"
  defp language_name(_), do: "the target language"

  defp call_llm(prompt, user_id, query_type) do
    prompt
    |> Client.generate()
    |> Client.track_usage(user_id, query_type)
    |> Client.parse_json()
  end

  defp parse_evaluation(%{"correct" => correct, "feedback" => feedback} = data) do
    {:ok,
     %{
       correct: correct == true,
       feedback: feedback,
       improved: Map.get(data, "improved")
     }}
  end

  defp parse_evaluation(_), do: {:error, "Invalid evaluation format"}
end

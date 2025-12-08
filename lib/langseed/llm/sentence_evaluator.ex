defmodule Langseed.LLM.SentenceEvaluator do
  @moduledoc """
  Evaluates user-written sentences using LLM.
  """

  alias Langseed.Language
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
  @spec evaluate(integer() | nil, Concept.t(), String.t(), MapSet.t()) ::
          {:ok, evaluation_result()} | {:error, String.t()}
  def evaluate(user_id, concept, user_sentence, known_words) do
    known_chars = Language.extract_chars(known_words)
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")

    prompt = build_prompt(concept, user_sentence, known_chars_list)

    case call_llm(prompt, user_id, "evaluate_sentence") do
      {:ok, data} -> parse_evaluation(data)
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_prompt(concept, user_sentence, known_chars_list) do
    """
    Evaluate this Chinese sentence written by a learner.

    Target word they should use: "#{concept.word}" (#{concept.meaning})
    Learner's sentence: "#{user_sentence}"
    Words the learner knows (characters): #{known_chars_list}

    Check if:
    1. The sentence uses "#{concept.word}" correctly
    2. The sentence is grammatically reasonable
    3. The sentence makes sense

    Respond ONLY with JSON (no markdown):
    {"correct": true/false, "feedback": "Chinese feedback for the learner", "improved": "optional improved version if incorrect"}

    Be encouraging! If mostly correct with small errors, still mark as correct but give tips.
    Use ONLY known characters in your feedback, or use emojis.
    """
  end

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

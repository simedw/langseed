defmodule Langseed.Practice.QuestionAudio do
  @moduledoc """
  Shared helpers for building audio sentences from questions.

  Consolidates the logic for extracting the spoken sentence from different
  question types to avoid duplication across LiveViews and workers.
  """

  @doc """
  Builds the sentence to generate audio for based on question type.

  - `yes_no`: Returns the question text directly (read the full question)
  - `multiple_choice`: Fills in the blank with the correct answer
  - Other types: Returns the question text directly
  """
  @spec sentence_for_question(map()) :: String.t()
  def sentence_for_question(question) do
    case question.question_type do
      "yes_no" ->
        question.question_text

      "multiple_choice" ->
        case parse_correct_index(question.correct_answer) do
          {:ok, index} when is_list(question.options) ->
            correct_word = Enum.at(question.options, index)

            if is_binary(correct_word) and correct_word != "" do
              String.replace(question.question_text, "____", correct_word)
            else
              question.question_text
            end

          _ ->
            question.question_text
        end

      _ ->
        question.question_text
    end
  end

  defp parse_correct_index(value) when is_integer(value), do: {:ok, value}

  defp parse_correct_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_correct_index(_value), do: :error
end

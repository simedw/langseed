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
        correct_word = Enum.at(question.options, String.to_integer(question.correct_answer))
        String.replace(question.question_text, "____", correct_word || "")

      _ ->
        question.question_text
    end
  end
end

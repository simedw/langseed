defmodule Langseed.LLM do
  @moduledoc """
  LLM integration for Chinese word analysis using Gemini.

  This module is a facade that delegates to specialized modules:
  - `Langseed.LLM.Client` - Low-level LLM client and usage tracking
  - `Langseed.LLM.WordAnalyzer` - Word analysis and explanation generation
  - `Langseed.LLM.QuestionGenerator` - Practice question generation
  - `Langseed.LLM.SentenceEvaluator` - User sentence evaluation
  """

  alias Langseed.LLM.{WordAnalyzer, QuestionGenerator, SentenceEvaluator}

  # Word Analysis

  @doc """
  Analyzes a Chinese word within its context sentence to extract
  pinyin, meaning, part of speech, and a self-referential explanation.

  The explanation will only use characters from the known_words set + emojis.

  Returns {:ok, analysis} or {:error, reason}
  """
  defdelegate analyze_word(user_id, word, context_sentence \\ nil, known_words \\ MapSet.new()),
    to: WordAnalyzer,
    as: :analyze

  @doc """
  Regenerates explanations for a word using only known vocabulary.
  Returns {:ok, [explanations]} or {:error, reason}
  """
  defdelegate regenerate_explanation(user_id, concept, known_words),
    to: WordAnalyzer

  # Question Generation

  @doc """
  Generates a Yes/No question about the target word using only known vocabulary.
  Returns {:ok, %{question: ..., answer: true/false, explanation: ...}} or {:error, reason}
  """
  defdelegate generate_yes_no_question(user_id, concept, known_words),
    to: QuestionGenerator,
    as: :generate_yes_no

  @doc """
  Generates a fill-in-the-blank question with multiple choice options.
  Returns {:ok, %{sentence: ..., options: [...], correct_index: 0-3}} or {:error, reason}
  """
  defdelegate generate_fill_blank_question(user_id, concept, known_words, distractor_words),
    to: QuestionGenerator,
    as: :generate_fill_blank

  # Sentence Evaluation

  @doc """
  Evaluates a sentence written by the user using the target word.
  Returns {:ok, %{correct: true/false, feedback: "...", improved: "..."}} or {:error, reason}
  """
  defdelegate evaluate_sentence(user_id, concept, user_sentence, known_words),
    to: SentenceEvaluator,
    as: :evaluate
end

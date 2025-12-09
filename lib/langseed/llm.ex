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
  Analyzes a word within its context sentence to extract
  pronunciation (pinyin for Chinese), meaning, part of speech, and explanations.

  The explanation will only use words from the known_words set + emojis.

  Returns {:ok, analysis} or {:error, reason}
  """
  def analyze_word(user_id, word, context_sentence \\ nil, known_words \\ MapSet.new(), language \\ "zh") do
    WordAnalyzer.analyze(user_id, word, context_sentence, known_words, language)
  end

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
  def generate_yes_no_question(user_id, concept, known_words, language \\ "zh") do
    QuestionGenerator.generate_yes_no(user_id, concept, known_words, language)
  end

  @doc """
  Generates a fill-in-the-blank question with multiple choice options.
  Returns {:ok, %{sentence: ..., options: [...], correct_index: 0-3}} or {:error, reason}
  """
  def generate_fill_blank_question(user_id, concept, known_words, distractor_words, language \\ "zh") do
    QuestionGenerator.generate_fill_blank(user_id, concept, known_words, distractor_words, language)
  end

  # Sentence Evaluation

  @doc """
  Evaluates a sentence written by the user using the target word.
  Returns {:ok, %{correct: true/false, feedback: "...", improved: "..."}} or {:error, reason}
  """
  def evaluate_sentence(user_id, concept, user_sentence, known_words, language \\ "zh") do
    SentenceEvaluator.evaluate(user_id, concept, user_sentence, known_words, language)
  end
end

defmodule Langseed.VocabularyFixtures do
  @moduledoc """
  This module defines test helpers for creating vocabulary entities.
  """

  alias Langseed.Vocabulary
  alias Langseed.Practice.Question
  alias Langseed.Accounts.Scope
  alias Langseed.Repo

  def valid_concept_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      word: "你好",
      pinyin: "nǐ hǎo",
      meaning: "hello",
      part_of_speech: "interjection",
      explanations: ["👋😊", "见面 说 ____"],
      explanation_quality: 4,
      understanding: 50
    })
  end

  def concept_fixture(user, attrs \\ %{}) do
    scope = %Scope{user: user, language: "zh"}
    attrs = valid_concept_attrs(attrs)
    {:ok, concept} = Vocabulary.create_concept(scope, attrs)
    concept
  end

  def concept_fixture_with_scope(scope, attrs \\ %{}) do
    attrs = valid_concept_attrs(attrs)
    {:ok, concept} = Vocabulary.create_concept(scope, attrs)
    concept
  end

  @doc """
  Creates a question fixture for a concept.
  Does not require LLM - creates directly in database.
  """
  def question_fixture(concept, user, attrs \\ %{}) do
    default_attrs = %{
      question_type: "yes_no",
      question_text: "这个句子对不对？我想去看你。",
      correct_answer: "true",
      options: nil,
      explanation: "The sentence is grammatically correct.",
      concept_id: concept.id,
      user_id: user.id
    }

    attrs = Map.merge(default_attrs, attrs)

    {:ok, question} =
      %Question{}
      |> Question.changeset(attrs)
      |> Repo.insert()

    question
  end

  @doc """
  Creates a multiple choice question fixture.
  """
  def multiple_choice_question_fixture(concept, user, attrs \\ %{}) do
    default_attrs = %{
      question_type: "multiple_choice",
      question_text: "我____去看你。",
      correct_answer: "0",
      options: ["想", "是", "很", "不"],
      explanation: "想 means 'want to'.",
      concept_id: concept.id,
      user_id: user.id
    }

    question_fixture(concept, user, Map.merge(default_attrs, attrs))
  end
end

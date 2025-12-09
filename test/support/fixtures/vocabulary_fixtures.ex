defmodule Langseed.VocabularyFixtures do
  @moduledoc """
  This module defines test helpers for creating vocabulary entities.
  """

  alias Langseed.Vocabulary
  alias Langseed.Accounts.Scope

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
end

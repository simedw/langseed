defmodule Langseed.VocabularyFixtures do
  @moduledoc """
  This module defines test helpers for creating vocabulary entities.
  """

  alias Langseed.Vocabulary

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
    attrs = valid_concept_attrs(attrs)
    {:ok, concept} = Vocabulary.create_concept(user, attrs)
    concept
  end
end

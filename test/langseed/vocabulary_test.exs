defmodule Langseed.VocabularyTest do
  use Langseed.DataCase

  alias Langseed.Vocabulary
  alias Langseed.Vocabulary.Concept

  import Langseed.AccountsFixtures
  import Langseed.VocabularyFixtures

  describe "list_concepts/1" do
    test "returns all concepts for a user" do
      user = user_fixture()
      concept = concept_fixture(user)

      concepts = Vocabulary.list_concepts(user)
      assert length(concepts) == 1
      assert hd(concepts).id == concept.id
    end

    test "returns empty list for nil user" do
      assert Vocabulary.list_concepts(nil) == []
    end

    test "does not return other users' concepts" do
      user1 = user_fixture()
      user2 = user_fixture()
      concept_fixture(user1)

      assert Vocabulary.list_concepts(user2) == []
    end
  end

  describe "get_concept!/2" do
    test "returns the concept for the given user and id" do
      user = user_fixture()
      concept = concept_fixture(user)

      fetched = Vocabulary.get_concept!(user, concept.id)
      assert fetched.id == concept.id
    end

    test "raises for nil user" do
      assert_raise RuntimeError, "Authentication required", fn ->
        Vocabulary.get_concept!(nil, 1)
      end
    end
  end

  describe "get_concept_by_word/2" do
    test "returns the concept for the given word" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "测试"})

      fetched = Vocabulary.get_concept_by_word(user, "测试")
      assert fetched.id == concept.id
    end

    test "returns nil for non-existent word" do
      user = user_fixture()
      assert Vocabulary.get_concept_by_word(user, "不存在") == nil
    end

    test "returns nil for nil user" do
      assert Vocabulary.get_concept_by_word(nil, "test") == nil
    end
  end

  describe "create_concept/2" do
    test "creates a concept with valid data" do
      user = user_fixture()
      attrs = valid_concept_attrs()

      assert {:ok, %Concept{} = concept} = Vocabulary.create_concept(user, attrs)
      assert concept.word == "你好"
      assert concept.pinyin == "nǐ hǎo"
      assert concept.meaning == "hello"
    end

    test "returns error for nil user" do
      attrs = valid_concept_attrs()
      assert {:error, "Authentication required"} = Vocabulary.create_concept(nil, attrs)
    end

    test "returns error for invalid data" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Vocabulary.create_concept(user, %{})
    end
  end

  describe "update_concept/2" do
    test "updates the concept with valid data" do
      user = user_fixture()
      concept = concept_fixture(user)

      assert {:ok, updated} = Vocabulary.update_concept(concept, %{meaning: "updated"})
      assert updated.meaning == "updated"
    end
  end

  describe "update_understanding/2" do
    test "updates the understanding level" do
      user = user_fixture()
      concept = concept_fixture(user, %{understanding: 30})

      assert {:ok, updated} = Vocabulary.update_understanding(concept, 75)
      assert updated.understanding == 75
    end
  end

  describe "delete_concept/1" do
    test "deletes the concept" do
      user = user_fixture()
      concept = concept_fixture(user)

      assert {:ok, %Concept{}} = Vocabulary.delete_concept(concept)
      assert Vocabulary.list_concepts(user) == []
    end
  end

  describe "known_words/1" do
    test "returns a MapSet of known words" do
      user = user_fixture()
      concept_fixture(user, %{word: "你好"})
      concept_fixture(user, %{word: "再见"})

      words = Vocabulary.known_words(user)
      assert MapSet.member?(words, "你好")
      assert MapSet.member?(words, "再见")
      assert MapSet.size(words) == 2
    end

    test "returns empty MapSet for nil user" do
      assert Vocabulary.known_words(nil) == MapSet.new()
    end
  end

  describe "known_words_with_understanding/1" do
    test "returns a map of word to understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "你好", understanding: 50})
      concept_fixture(user, %{word: "再见", understanding: 75})

      words = Vocabulary.known_words_with_understanding(user)
      assert words["你好"] == 50
      assert words["再见"] == 75
    end

    test "returns empty map for nil user" do
      assert Vocabulary.known_words_with_understanding(nil) == %{}
    end
  end

  describe "word_known?/2" do
    test "returns true for known word" do
      user = user_fixture()
      concept_fixture(user, %{word: "测试"})

      assert Vocabulary.word_known?(user, "测试")
    end

    test "returns false for unknown word" do
      user = user_fixture()
      refute Vocabulary.word_known?(user, "不存在")
    end

    test "returns false for nil user" do
      refute Vocabulary.word_known?(nil, "test")
    end
  end
end

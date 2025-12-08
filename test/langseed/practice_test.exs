defmodule Langseed.PracticeTest do
  use Langseed.DataCase

  alias Langseed.Practice

  import Langseed.AccountsFixtures
  import Langseed.VocabularyFixtures

  describe "get_next_concept/1" do
    test "returns concept with lowest understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "高", understanding: 50})
      low = concept_fixture(user, %{word: "低", understanding: 10})

      next = Practice.get_next_concept(user)
      assert next.id == low.id
    end

    test "excludes paused concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})
      active = concept_fixture(user, %{word: "活跃", understanding: 30})

      next = Practice.get_next_concept(user)
      assert next.id == active.id
    end

    test "returns nil when all concepts are paused" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})

      assert Practice.get_next_concept(user) == nil
    end

    test "returns nil for nil user" do
      assert Practice.get_next_concept(nil) == nil
    end

    test "excludes concepts with understanding above 60" do
      user = user_fixture()
      concept_fixture(user, %{word: "高手", understanding: 80})

      assert Practice.get_next_concept(user) == nil
    end
  end

  describe "get_practice_concepts/2" do
    test "returns concepts ordered by understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "中", understanding: 30})
      concept_fixture(user, %{word: "低", understanding: 10})
      concept_fixture(user, %{word: "高", understanding: 50})

      concepts = Practice.get_practice_concepts(user, 10)
      words = Enum.map(concepts, & &1.word)
      assert words == ["低", "中", "高"]
    end

    test "excludes paused concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})
      concept_fixture(user, %{word: "活跃", understanding: 30})

      concepts = Practice.get_practice_concepts(user, 10)
      words = Enum.map(concepts, & &1.word)
      assert words == ["活跃"]
    end

    test "respects limit" do
      user = user_fixture()
      concept_fixture(user, %{word: "一", understanding: 10})
      concept_fixture(user, %{word: "二", understanding: 20})
      concept_fixture(user, %{word: "三", understanding: 30})

      concepts = Practice.get_practice_concepts(user, 2)
      assert length(concepts) == 2
    end
  end

  describe "get_quiz_concepts/1" do
    test "excludes paused concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})
      concept_fixture(user, %{word: "活跃", understanding: 30})

      concepts = Practice.get_quiz_concepts(user)
      words = Enum.map(concepts, & &1.word)
      assert words == ["活跃"]
    end

    test "excludes concepts with 0 understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "新", understanding: 0})
      concept_fixture(user, %{word: "学", understanding: 10})

      concepts = Practice.get_quiz_concepts(user)
      words = Enum.map(concepts, & &1.word)
      assert words == ["学"]
    end
  end
end

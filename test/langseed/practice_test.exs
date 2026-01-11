defmodule Langseed.PracticeTest do
  use Langseed.DataCase

  alias Langseed.Practice
  alias Langseed.Accounts.Scope

  import Langseed.AccountsFixtures
  import Langseed.VocabularyFixtures

  defp scope_for(user), do: %Scope{user: user, language: "zh"}

  describe "get_next_concept/1" do
    test "returns concept with lowest understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "高", understanding: 50})
      low = concept_fixture(user, %{word: "低", understanding: 10})

      next = Practice.get_next_concept(scope_for(user))
      assert next.id == low.id
    end

    test "excludes paused concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})
      active = concept_fixture(user, %{word: "活跃", understanding: 30})

      next = Practice.get_next_concept(scope_for(user))
      assert next.id == active.id
    end

    test "returns nil when all concepts are paused" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})

      assert Practice.get_next_concept(scope_for(user)) == nil
    end

    test "returns nil for nil user" do
      assert Practice.get_next_concept(nil) == nil
    end

    test "excludes concepts with understanding above 60" do
      user = user_fixture()
      concept_fixture(user, %{word: "高手", understanding: 80})

      assert Practice.get_next_concept(scope_for(user)) == nil
    end
  end

  describe "get_practice_concepts/2" do
    test "returns concepts ordered by understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "中", understanding: 30})
      concept_fixture(user, %{word: "低", understanding: 10})
      concept_fixture(user, %{word: "高", understanding: 50})

      concepts = Practice.get_practice_concepts(scope_for(user), 10)
      words = Enum.map(concepts, & &1.word)
      assert words == ["低", "中", "高"]
    end

    test "excludes paused concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})
      concept_fixture(user, %{word: "活跃", understanding: 30})

      concepts = Practice.get_practice_concepts(scope_for(user), 10)
      words = Enum.map(concepts, & &1.word)
      assert words == ["活跃"]
    end

    test "respects limit" do
      user = user_fixture()
      concept_fixture(user, %{word: "一", understanding: 10})
      concept_fixture(user, %{word: "二", understanding: 20})
      concept_fixture(user, %{word: "三", understanding: 30})

      concepts = Practice.get_practice_concepts(scope_for(user), 2)
      assert length(concepts) == 2
    end
  end

  describe "get_quiz_concepts/1" do
    test "excludes paused concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "暂停", understanding: 10, paused: true})
      concept_fixture(user, %{word: "活跃", understanding: 30})

      concepts = Practice.get_quiz_concepts(scope_for(user))
      words = Enum.map(concepts, & &1.word)
      assert words == ["活跃"]
    end

    test "excludes concepts with 0 understanding" do
      user = user_fixture()
      concept_fixture(user, %{word: "新", understanding: 0})
      concept_fixture(user, %{word: "学", understanding: 10})

      concepts = Practice.get_quiz_concepts(scope_for(user))
      words = Enum.map(concepts, & &1.word)
      assert words == ["学"]
    end
  end

  describe "generate_question/2" do
    test "returns error for nil scope" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "测试"})

      assert {:error, "Authentication required"} = Practice.generate_question(nil, concept)
    end
  end

  describe "generate_question/3 with specific type" do
    test "returns error for unknown question type" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "未知"})

      assert {:error, "Unknown question type: invalid"} =
               Practice.generate_question(scope_for(user), concept, "invalid")
    end

    test "returns error for nil scope" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "测试"})

      assert {:error, "Authentication required"} =
               Practice.generate_question(nil, concept, "yes_no")
    end
  end

  describe "get_or_generate_question/2" do
    test "returns existing unused question" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "现有"})

      # Create question using fixture (no LLM needed)
      existing = question_fixture(concept, user)

      # get_or_generate should return the existing one
      {:ok, retrieved} = Practice.get_or_generate_question(scope_for(user), concept)
      assert retrieved.id == existing.id
    end

    test "returns error for nil scope" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "测试"})

      assert {:error, "Authentication required"} = Practice.get_or_generate_question(nil, concept)
    end
  end

  describe "get_unused_question/1" do
    test "returns unused question for concept" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "问题"})
      question = question_fixture(concept, user)

      result = Practice.get_unused_question(concept.id)
      assert result.id == question.id
    end

    test "returns nil when no unused questions" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "空"})

      assert Practice.get_unused_question(concept.id) == nil
    end

    test "excludes used questions" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "已用"})
      question_fixture(concept, user, %{used_at: DateTime.utc_now()})

      assert Practice.get_unused_question(concept.id) == nil
    end
  end

  describe "count_unused_questions/2" do
    test "counts unused questions for concept and type" do
      user = user_fixture()
      concept = concept_fixture(user, %{word: "计数"})

      # Create 2 yes_no questions
      question_fixture(concept, user, %{question_type: "yes_no"})
      question_fixture(concept, user, %{question_type: "yes_no"})

      # Create 1 multiple_choice question
      multiple_choice_question_fixture(concept, user)

      assert Practice.count_unused_questions(concept.id, "yes_no") == 2
      assert Practice.count_unused_questions(concept.id, "multiple_choice") == 1
    end
  end
end

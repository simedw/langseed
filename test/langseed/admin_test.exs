defmodule Langseed.AdminTest do
  use Langseed.DataCase

  alias Langseed.Admin

  import Langseed.AccountsFixtures
  import Langseed.VocabularyFixtures

  describe "total_users/0" do
    test "returns 0 when no users" do
      assert Admin.total_users() == 0
    end

    test "counts users" do
      user_fixture()
      user_fixture()

      assert Admin.total_users() == 2
    end
  end

  describe "engagement_stats/0" do
    test "returns stats with no users" do
      stats = Admin.engagement_stats()

      assert stats.total_users == 0
      assert stats.practiced_at_least_once == 0
      assert stats.added_words == 0
      assert stats.active_7d == 0
      assert stats.active_30d == 0
    end

    test "counts users who practiced" do
      user = user_fixture()
      concept = concept_fixture(user)
      _question = question_fixture(concept, user, %{used_at: DateTime.utc_now()})

      stats = Admin.engagement_stats()

      assert stats.total_users == 1
      assert stats.practiced_at_least_once == 1
    end

    test "counts users who added words beyond starter pack" do
      user = user_fixture()

      # Create 31 concepts (more than the 30 starter pack threshold)
      for i <- 1..31 do
        concept_fixture(user, %{word: "word#{i}"})
      end

      stats = Admin.engagement_stats()

      assert stats.added_words == 1
    end

    test "does not count users at or below starter pack threshold" do
      user = user_fixture()

      # Create exactly 30 concepts (at the threshold)
      for i <- 1..30 do
        concept_fixture(user, %{word: "word#{i}"})
      end

      stats = Admin.engagement_stats()

      assert stats.added_words == 0
    end
  end

  describe "user_funnel/0" do
    test "returns funnel with no users" do
      funnel = Admin.user_funnel()

      assert funnel.signed_up_only == 0
      assert funnel.added_words == 0
      assert funnel.tried_once == 0
      assert funnel.active == 0
    end

    test "categorizes users correctly" do
      # User who only signed up (no words beyond default, no practice)
      _signup_only = user_fixture()

      funnel = Admin.user_funnel()

      assert funnel.signed_up_only == 1
    end
  end

  describe "total_words_learned/0" do
    test "returns 0 with no concepts" do
      assert Admin.total_words_learned() == 0
    end

    test "counts all concepts" do
      user = user_fixture()
      concept_fixture(user, %{word: "一"})
      concept_fixture(user, %{word: "二"})

      assert Admin.total_words_learned() == 2
    end
  end

  describe "total_questions_answered/0" do
    test "returns 0 with no answered questions" do
      assert Admin.total_questions_answered() == 0
    end

    test "counts only answered questions" do
      user = user_fixture()
      concept = concept_fixture(user)

      # Unanswered question
      question_fixture(concept, user)
      # Answered question
      question_fixture(concept, user, %{used_at: DateTime.utc_now()})

      assert Admin.total_questions_answered() == 1
    end
  end

  describe "users_with_metrics/0" do
    test "returns empty list with no users" do
      assert Admin.users_with_metrics() == []
    end

    test "returns user metrics" do
      user = user_fixture()
      concept = concept_fixture(user)
      question_fixture(concept, user, %{used_at: DateTime.utc_now()})

      [metrics] = Admin.users_with_metrics()

      assert metrics.id == user.id
      assert metrics.word_count == 1
      assert metrics.practice_count == 1
    end
  end

  describe "language_distribution/0" do
    test "returns empty list with no concepts" do
      assert Admin.language_distribution() == []
    end

    test "groups concepts by language" do
      user = user_fixture()
      concept_fixture(user, %{word: "你好"})
      concept_fixture(user, %{word: "再见"})

      [dist] = Admin.language_distribution()

      assert dist.language == "zh"
      assert dist.count == 2
    end
  end
end

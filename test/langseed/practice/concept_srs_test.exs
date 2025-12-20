defmodule Langseed.Practice.ConceptSRSTest do
  use Langseed.DataCase, async: true

  alias Langseed.Practice.ConceptSRS

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        concept_id: 1,
        user_id: 1,
        question_type: "pinyin",
        tier: 0
      }

      changeset = ConceptSRS.changeset(%ConceptSRS{}, attrs)
      assert changeset.valid?
    end

    test "requires concept_id, user_id, and question_type" do
      changeset = ConceptSRS.changeset(%ConceptSRS{}, %{})
      refute changeset.valid?
      assert %{concept_id: ["can't be blank"]} = errors_on(changeset)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
      assert %{question_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates question_type is in allowed list" do
      attrs = %{
        concept_id: 1,
        user_id: 1,
        question_type: "invalid_type",
        tier: 0
      }

      changeset = ConceptSRS.changeset(%ConceptSRS{}, attrs)
      refute changeset.valid?
      assert %{question_type: ["is invalid"]} = errors_on(changeset)
    end

    test "validates tier is between 0 and 7" do
      attrs = %{concept_id: 1, user_id: 1, question_type: "pinyin", tier: 8}
      changeset = ConceptSRS.changeset(%ConceptSRS{}, attrs)
      refute changeset.valid?

      attrs = %{concept_id: 1, user_id: 1, question_type: "pinyin", tier: -1}
      changeset = ConceptSRS.changeset(%ConceptSRS{}, attrs)
      refute changeset.valid?
    end
  end

  describe "tier_to_interval/1" do
    test "returns correct intervals for each tier" do
      assert ConceptSRS.tier_to_interval(0) == 10
      assert ConceptSRS.tier_to_interval(1) == 60
      assert ConceptSRS.tier_to_interval(2) == 480
      assert ConceptSRS.tier_to_interval(3) == 1440
      assert ConceptSRS.tier_to_interval(4) == 4320
      assert ConceptSRS.tier_to_interval(5) == 10_080
      assert ConceptSRS.tier_to_interval(6) == 43_200
      assert ConceptSRS.tier_to_interval(7) == nil
    end
  end

  describe "tier_to_percent/1" do
    test "converts tier to percentage" do
      assert ConceptSRS.tier_to_percent(0) == 0
      assert ConceptSRS.tier_to_percent(1) == 14
      assert ConceptSRS.tier_to_percent(3) == 43
      assert ConceptSRS.tier_to_percent(7) == 100
    end
  end

  describe "update_tier/2" do
    test "increments tier on correct answer" do
      assert ConceptSRS.update_tier(0, true) == 1
      assert ConceptSRS.update_tier(3, true) == 4
      assert ConceptSRS.update_tier(6, true) == 7
    end

    test "caps tier at 7" do
      assert ConceptSRS.update_tier(7, true) == 7
    end

    test "demotes tier on incorrect answer" do
      assert ConceptSRS.update_tier(1, false) == 0
      assert ConceptSRS.update_tier(5, false) == 3
    end
  end

  describe "demote_tier/1" do
    test "gentle penalty for early learning (tiers 0-2)" do
      assert ConceptSRS.demote_tier(0) == 0
      assert ConceptSRS.demote_tier(1) == 0
      assert ConceptSRS.demote_tier(2) == 1
    end

    test "serious penalty for late learning (tiers 3-6)" do
      assert ConceptSRS.demote_tier(3) == 1
      assert ConceptSRS.demote_tier(4) == 2
      assert ConceptSRS.demote_tier(5) == 3
      assert ConceptSRS.demote_tier(6) == 4
    end
  end

  describe "calculate_next_review/1" do
    test "calculates next review based on tier" do
      now = DateTime.utc_now()

      next_review = ConceptSRS.calculate_next_review(0)
      diff = DateTime.diff(next_review, now, :minute)
      assert diff >= 9 and diff <= 11

      next_review = ConceptSRS.calculate_next_review(1)
      diff = DateTime.diff(next_review, now, :minute)
      assert diff >= 59 and diff <= 61
    end

    test "returns nil for tier 7 (graduated)" do
      assert ConceptSRS.calculate_next_review(7) == nil
    end
  end

  describe "update_streak_and_lapses/2" do
    test "increments streak on correct answer" do
      srs = %ConceptSRS{streak: 2, lapses: 1}
      result = ConceptSRS.update_streak_and_lapses(srs, true)
      assert result.streak == 3
      assert result.lapses == 1
    end

    test "resets streak and increments lapses on incorrect answer" do
      srs = %ConceptSRS{streak: 5, lapses: 2}
      result = ConceptSRS.update_streak_and_lapses(srs, false)
      assert result.streak == 0
      assert result.lapses == 3
    end
  end

  describe "question_types_for_language/1" do
    test "includes pinyin for Chinese" do
      types = ConceptSRS.question_types_for_language("zh")
      assert "pinyin" in types
      assert "yes_no" in types
      assert "multiple_choice" in types
      assert length(types) == 3
    end

    test "excludes pinyin for other languages" do
      types = ConceptSRS.question_types_for_language("es")
      refute "pinyin" in types
      assert "yes_no" in types
      assert "multiple_choice" in types
      assert length(types) == 2
    end
  end

  describe "format_question_type/1" do
    test "formats known question types" do
      assert ConceptSRS.format_question_type("pinyin") == "Pinyin"
      assert ConceptSRS.format_question_type("yes_no") == "Yes/No"
      assert ConceptSRS.format_question_type("multiple_choice") == "Multiple Choice"
    end

    test "returns unknown types as-is" do
      assert ConceptSRS.format_question_type("unknown") == "unknown"
    end
  end
end

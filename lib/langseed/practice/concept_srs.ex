defmodule Langseed.Practice.ConceptSRS do
  @moduledoc """
  Schema for SRS (Spaced Repetition System) tracking per concept and question type.

  Each concept can have multiple SRS records, one for each question type:
  - Chinese: pinyin, yes_no, multiple_choice (3 types)
  - Other languages: yes_no, multiple_choice (2 types)

  Progress is tracked using discrete tiers (0-7) that map to intervals:
  - Tier 0: 10 minutes
  - Tier 1: 1 hour
  - Tier 2: 8 hours
  - Tier 3: 1 day
  - Tier 4: 3 days
  - Tier 5: 7 days
  - Tier 6: 30 days
  - Tier 7: Graduated (no more reviews)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @question_types ~w(pinyin yes_no multiple_choice)
  @tier_intervals_minutes [10, 60, 480, 1440, 4320, 10_080, 43_200, nil]

  schema "concept_srs" do
    field :question_type, :string
    field :tier, :integer, default: 0
    field :next_review, :utc_datetime
    field :lapses, :integer, default: 0
    field :streak, :integer, default: 0
    field :ease, :float, default: 2.5

    belongs_to :concept, Langseed.Vocabulary.Concept
    belongs_to :user, Langseed.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(concept_srs, attrs) do
    concept_srs
    |> cast(attrs, [
      :concept_id,
      :user_id,
      :question_type,
      :tier,
      :next_review,
      :lapses,
      :streak,
      :ease
    ])
    |> validate_required([:concept_id, :user_id, :question_type])
    |> validate_inclusion(:question_type, @question_types)
    |> validate_number(:tier, greater_than_or_equal_to: 0, less_than_or_equal_to: 7)
    |> foreign_key_constraint(:concept_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :concept_id, :question_type])
  end

  # --- Tier Calculation Helpers ---

  @doc """
  Returns the interval in minutes for a given tier.
  Tier 7 (graduated) returns nil.
  """
  def tier_to_interval(tier) when tier >= 0 and tier <= 7 do
    Enum.at(@tier_intervals_minutes, tier)
  end

  @doc """
  Returns the display percentage for a given tier.
  Tier 0 = 0%, Tier 7 = 100%
  """
  def tier_to_percent(tier) when tier >= 0 and tier <= 7 do
    round(tier / 7 * 100)
  end

  @doc """
  Calculates the new tier after answering correctly (promote) or incorrectly (demote).

  Correct: +1 tier (max 7)
  Wrong: -1 tier for tiers 0-2 (gentle), -2 tiers for tiers 3-6 (meaningful penalty)
  """
  def update_tier(current_tier, correct?) do
    if correct? do
      min(current_tier + 1, 7)
    else
      demote_tier(current_tier)
    end
  end

  @doc """
  Demotes a tier with adaptive penalty:
  - Early learning (0-2): gentle -1 penalty
  - Late learning (3-6): serious -2 penalty
  """
  def demote_tier(current_tier) do
    penalty = if current_tier >= 3, do: 2, else: 1
    max(current_tier - penalty, 0)
  end

  @doc """
  Calculates the next review datetime based on the tier.
  Tier 7 returns nil (graduated, no more reviews).
  """
  def calculate_next_review(tier) do
    case tier_to_interval(tier) do
      nil -> nil
      minutes -> DateTime.add(DateTime.utc_now(), minutes * 60, :second)
    end
  end

  @doc """
  Updates streak and lapses based on answer correctness.
  Correct: increment streak, keep lapses
  Wrong: reset streak to 0, increment lapses
  """
  def update_streak_and_lapses(srs_record, correct?) do
    if correct? do
      %{streak: srs_record.streak + 1, lapses: srs_record.lapses}
    else
      %{streak: 0, lapses: srs_record.lapses + 1}
    end
  end

  @doc """
  Returns the question types for a given language.
  Chinese includes pinyin, other languages don't.
  """
  def question_types_for_language("zh"), do: ["pinyin", "yes_no", "multiple_choice"]
  def question_types_for_language(_language), do: ["yes_no", "multiple_choice"]

  def question_types, do: @question_types

  @doc """
  Formats a question type as a user-friendly string.
  """
  @spec format_question_type(String.t()) :: String.t()
  def format_question_type("pinyin"),
    do: Gettext.dgettext(LangseedWeb.Gettext, "default", "Pinyin")

  def format_question_type("yes_no"),
    do: Gettext.dgettext(LangseedWeb.Gettext, "default", "Yes/No")

  def format_question_type("multiple_choice"),
    do: Gettext.dgettext(LangseedWeb.Gettext, "default", "Multiple Choice")

  def format_question_type(type), do: type
end

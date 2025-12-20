defmodule Langseed.Practice.Question do
  @moduledoc """
  Schema for practice questions (yes/no, multiple-choice, sentence) linked to concepts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @question_types ~w(yes_no multiple_choice sentence)

  schema "questions" do
    field :question_type, :string
    field :question_text, :string
    field :correct_answer, :string
    field :options, {:array, :string}, default: []
    field :explanation, :string
    # Legacy field - use used_at for new code
    field :used, :boolean, default: false
    # Timestamp when question was used (race-condition safe)
    field :used_at, :utc_datetime

    belongs_to :concept, Langseed.Vocabulary.Concept
    belongs_to :user, Langseed.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(question, attrs) do
    question
    |> cast(attrs, [
      :concept_id,
      :question_type,
      :question_text,
      :correct_answer,
      :options,
      :explanation,
      :used,
      :used_at,
      :user_id
    ])
    |> validate_required([:concept_id, :question_type, :question_text])
    |> validate_inclusion(:question_type, @question_types)
    |> foreign_key_constraint(:concept_id)
  end

  def question_types, do: @question_types
end

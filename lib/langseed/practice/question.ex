defmodule Langseed.Practice.Question do
  use Ecto.Schema
  import Ecto.Changeset

  @question_types ~w(yes_no fill_blank sentence)

  schema "questions" do
    field :question_type, :string
    field :question_text, :string
    field :correct_answer, :string
    field :options, {:array, :string}, default: []
    field :explanation, :string
    field :used, :boolean, default: false

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
      :user_id
    ])
    |> validate_required([:concept_id, :question_type, :question_text])
    |> validate_inclusion(:question_type, @question_types)
    |> foreign_key_constraint(:concept_id)
  end

  def question_types, do: @question_types
end

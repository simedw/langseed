defmodule Langseed.Vocabulary.Concept do
  @moduledoc """
  Schema for vocabulary concepts (words) with pinyin, meaning, and explanations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @parts_of_speech ~w(noun verb adjective adverb pronoun preposition conjunction particle numeral measure_word interjection other)

  schema "concepts" do
    field :word, :string
    field :pinyin, :string
    field :meaning, :string
    field :part_of_speech, :string
    # Multiple explanations using different approaches
    field :explanations, {:array, :string}, default: []
    field :example_sentence, :string
    field :understanding, :integer, default: 0
    # AI's satisfaction with the explanation (1-5 scale)
    field :explanation_quality, :integer
    # Words the AI wishes it had to make a better explanation
    field :desired_words, {:array, :string}, default: []

    belongs_to :user, Langseed.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [
      :word,
      :pinyin,
      :meaning,
      :part_of_speech,
      :explanations,
      :example_sentence,
      :understanding,
      :explanation_quality,
      :desired_words,
      :user_id
    ])
    |> validate_required([:word, :pinyin, :meaning, :part_of_speech])
    |> validate_inclusion(:part_of_speech, @parts_of_speech)
    |> validate_number(:understanding, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:explanation_quality,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5
    )
  end

  def parts_of_speech, do: @parts_of_speech
end

defmodule Langseed.Analytics.LlmQuery do
  use Ecto.Schema
  import Ecto.Changeset

  @query_types ~w(analyze_word regenerate_explanation yes_no_question fill_blank_question evaluate_sentence)

  schema "llm_queries" do
    field :query_type, :string
    field :model, :string
    field :input_tokens, :integer
    field :output_tokens, :integer

    belongs_to :user, Langseed.Accounts.User

    timestamps()
  end

  def changeset(llm_query, attrs) do
    llm_query
    |> cast(attrs, [:user_id, :query_type, :model, :input_tokens, :output_tokens])
    |> validate_required([:query_type, :model])
    |> validate_inclusion(:query_type, @query_types)
  end

  def query_types, do: @query_types
end

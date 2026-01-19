defmodule Langseed.Vocabulary.WordImport do
  @moduledoc """
  Schema for tracking async word import jobs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Langseed.Accounts.User

  @statuses ~w(pending processing completed failed)

  schema "word_imports" do
    field :language, :string
    field :word, :string
    field :context, :string
    field :status, :string, default: "pending"
    field :error, :string

    belongs_to :user, User

    timestamps()
  end

  def changeset(word_import, attrs) do
    word_import
    |> cast(attrs, [:word, :language, :context, :status, :error, :user_id])
    |> validate_required([:word, :language, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
  end

  def statuses, do: @statuses
end

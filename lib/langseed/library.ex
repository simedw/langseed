defmodule Langseed.Library do
  @moduledoc """
  The Library context for managing saved texts.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Library.Text

  @doc """
  Returns the list of texts, ordered by most recently updated.
  """
  def list_texts do
    Text
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  @doc """
  Returns recent texts (limited count), ordered by most recently updated.
  """
  def list_recent_texts(limit \\ 5) do
    Text
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single text.

  Raises `Ecto.NoResultsError` if the Text does not exist.
  """
  def get_text!(id), do: Repo.get!(Text, id)

  @doc """
  Gets a single text, returns nil if not found.
  """
  def get_text(id), do: Repo.get(Text, id)

  @doc """
  Creates a text. Title is auto-generated from content if not provided.
  """
  def create_text(attrs \\ %{}) do
    %Text{}
    |> Text.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a text.
  """
  def update_text(%Text{} = text, attrs) do
    text
    |> Text.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a text.
  """
  def delete_text(%Text{} = text) do
    Repo.delete(text)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking text changes.
  """
  def change_text(%Text{} = text, attrs \\ %{}) do
    Text.changeset(text, attrs)
  end
end

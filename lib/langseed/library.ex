defmodule Langseed.Library do
  @moduledoc """
  The Library context for managing saved texts.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Library.Text
  alias Langseed.Accounts.User

  @doc """
  Returns the list of texts for a user, ordered by most recently updated.
  """
  def list_texts(%User{} = user) do
    Text
    |> where(user_id: ^user.id)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def list_texts(nil), do: []

  @doc """
  Returns recent texts for a user (limited count), ordered by most recently updated.
  """
  def list_recent_texts(user, limit \\ 5)

  def list_recent_texts(%User{} = user, limit) do
    Text
    |> where(user_id: ^user.id)
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_recent_texts(nil, _limit), do: []

  @doc """
  Gets a single text for a user.
  """
  def get_text!(%User{} = user, id) do
    Text
    |> where(user_id: ^user.id, id: ^id)
    |> Repo.one!()
  end

  def get_text!(nil, _id), do: raise("Authentication required")

  @doc """
  Gets a single text, returns nil if not found.
  """
  def get_text(%User{} = user, id) do
    Repo.get_by(Text, id: id, user_id: user.id)
  end

  def get_text(nil, _id), do: nil

  @doc """
  Creates a text for a user.
  """
  def create_text(%User{} = user, attrs) do
    %Text{}
    |> Text.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def create_text(nil, _attrs), do: {:error, "Authentication required"}

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

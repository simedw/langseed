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
  @spec list_texts(User.t() | nil) :: [Text.t()]
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
  @spec list_recent_texts(User.t() | nil, integer()) :: [Text.t()]
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
  Raises if not found.
  """
  @spec get_text!(User.t(), term()) :: Text.t()
  def get_text!(%User{} = user, id) do
    Text
    |> where(user_id: ^user.id, id: ^id)
    |> Repo.one!()
  end

  def get_text!(nil, _id), do: raise("Authentication required")

  @doc """
  Gets a single text, returns nil if not found.
  """
  @spec get_text(User.t() | nil, term()) :: Text.t() | nil
  def get_text(%User{} = user, id) do
    Repo.get_by(Text, id: id, user_id: user.id)
  end

  def get_text(nil, _id), do: nil

  @doc """
  Creates a text for a user.
  """
  @spec create_text(User.t() | nil, map()) ::
          {:ok, Text.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_text(%User{} = user, attrs) do
    %Text{}
    |> Text.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def create_text(nil, _attrs), do: {:error, "Authentication required"}

  @doc """
  Updates a text.
  """
  @spec update_text(Text.t(), map()) :: {:ok, Text.t()} | {:error, Ecto.Changeset.t()}
  def update_text(%Text{} = text, attrs) do
    text
    |> Text.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a text.
  """
  @spec delete_text(Text.t()) :: {:ok, Text.t()} | {:error, Ecto.Changeset.t()}
  def delete_text(%Text{} = text) do
    Repo.delete(text)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking text changes.
  """
  @spec change_text(Text.t(), map()) :: Ecto.Changeset.t()
  def change_text(%Text{} = text, attrs \\ %{}) do
    Text.changeset(text, attrs)
  end
end

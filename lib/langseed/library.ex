defmodule Langseed.Library do
  @moduledoc """
  The Library context for managing saved texts.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Library.Text
  alias Langseed.Accounts.Scope

  @doc """
  Returns the list of texts for a scope (user + language), ordered by most recently updated.
  """
  @spec list_texts(Scope.t() | nil) :: [Text.t()]
  def list_texts(%Scope{user: user, language: language}) do
    Text
    |> where(user_id: ^user.id, language: ^language)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def list_texts(nil), do: []

  @doc """
  Returns recent texts for a scope (limited count), ordered by most recently updated.
  """
  @spec list_recent_texts(Scope.t() | nil, integer()) :: [Text.t()]
  def list_recent_texts(scope, limit \\ 5)

  def list_recent_texts(%Scope{user: user, language: language}, limit) do
    Text
    |> where(user_id: ^user.id, language: ^language)
    |> order_by(desc: :updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_recent_texts(nil, _limit), do: []

  @doc """
  Gets a single text for a scope.
  Raises if not found.
  """
  @spec get_text!(Scope.t(), term()) :: Text.t()
  def get_text!(%Scope{user: user}, id) do
    Text
    |> where(user_id: ^user.id, id: ^id)
    |> Repo.one!()
  end

  def get_text!(nil, _id), do: raise("Authentication required")

  @doc """
  Gets a single text, returns nil if not found.
  """
  @spec get_text(Scope.t() | nil, term()) :: Text.t() | nil
  def get_text(%Scope{user: user}, id) do
    Repo.get_by(Text, id: id, user_id: user.id)
  end

  def get_text(nil, _id), do: nil

  @doc """
  Creates a text for a scope (user + language).
  """
  @spec create_text(Scope.t() | nil, map()) ::
          {:ok, Text.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_text(%Scope{user: user, language: language}, attrs) do
    %Text{}
    |> Text.changeset(attrs |> Map.put(:user_id, user.id) |> Map.put(:language, language))
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

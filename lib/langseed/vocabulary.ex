defmodule Langseed.Vocabulary do
  @moduledoc """
  The Vocabulary context for managing Chinese language concepts.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Vocabulary.Concept
  alias Langseed.Accounts.User

  @doc """
  Returns the list of concepts for a user, sorted by understanding (descending).
  """
  @spec list_concepts(User.t() | nil) :: [Concept.t()]
  def list_concepts(%User{} = user) do
    Concept
    |> where(user_id: ^user.id)
    |> order_by(desc: :understanding, asc: :word)
    |> Repo.all()
  end

  def list_concepts(nil), do: []

  @doc """
  Gets a single concept for a user.
  Raises if not found.
  """
  @spec get_concept!(User.t(), term()) :: Concept.t()
  def get_concept!(%User{} = user, id) do
    Concept
    |> where(user_id: ^user.id, id: ^id)
    |> Repo.one!()
  end

  def get_concept!(nil, _id), do: raise("Authentication required")

  @doc """
  Gets a concept by word for a user.
  """
  @spec get_concept_by_word(User.t() | nil, String.t()) :: Concept.t() | nil
  def get_concept_by_word(%User{} = user, word) do
    Repo.get_by(Concept, word: word, user_id: user.id)
  end

  def get_concept_by_word(nil, _word), do: nil

  @doc """
  Creates a concept for a user.
  """
  @spec create_concept(User.t() | nil, map()) ::
          {:ok, Concept.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_concept(%User{} = user, attrs) do
    %Concept{}
    |> Concept.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  def create_concept(nil, _attrs), do: {:error, "Authentication required"}

  @doc """
  Updates a concept.
  """
  @spec update_concept(Concept.t(), map()) :: {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def update_concept(%Concept{} = concept, attrs) do
    concept
    |> Concept.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the understanding level of a concept.
  """
  @spec update_understanding(Concept.t(), integer()) ::
          {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def update_understanding(%Concept{} = concept, level) when level >= 0 and level <= 100 do
    update_concept(concept, %{understanding: level})
  end

  @doc """
  Deletes a concept.
  """
  @spec delete_concept(Concept.t()) :: {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def delete_concept(%Concept{} = concept) do
    Repo.delete(concept)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking concept changes.
  """
  @spec change_concept(Concept.t(), map()) :: Ecto.Changeset.t()
  def change_concept(%Concept{} = concept, attrs \\ %{}) do
    Concept.changeset(concept, attrs)
  end

  @doc """
  Returns a MapSet of all known words for a user.
  """
  @spec known_words(User.t() | nil) :: MapSet.t()
  def known_words(%User{} = user) do
    Concept
    |> where(user_id: ^user.id)
    |> select([c], c.word)
    |> Repo.all()
    |> MapSet.new()
  end

  def known_words(nil), do: MapSet.new()

  @doc """
  Returns a map of word -> understanding level for a user.
  """
  @spec known_words_with_understanding(User.t() | nil) :: %{String.t() => integer()}
  def known_words_with_understanding(%User{} = user) do
    Concept
    |> where(user_id: ^user.id)
    |> select([c], {c.word, c.understanding})
    |> Repo.all()
    |> Map.new()
  end

  def known_words_with_understanding(nil), do: %{}

  @doc """
  Returns true if a word exists in vocabulary for a user.
  """
  @spec word_known?(User.t() | nil, String.t()) :: boolean()
  def word_known?(%User{} = user, word) do
    Repo.exists?(from c in Concept, where: c.word == ^word and c.user_id == ^user.id)
  end

  def word_known?(nil, _word), do: false
end

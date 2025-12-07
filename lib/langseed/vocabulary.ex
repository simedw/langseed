defmodule Langseed.Vocabulary do
  @moduledoc """
  The Vocabulary context for managing Chinese language concepts.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Vocabulary.Concept

  @doc """
  Returns the list of concepts sorted by understanding (descending).
  """
  def list_concepts do
    Concept
    |> order_by(desc: :understanding, asc: :word)
    |> Repo.all()
  end

  @doc """
  Gets a single concept.

  Raises `Ecto.NoResultsError` if the Concept does not exist.
  """
  def get_concept!(id), do: Repo.get!(Concept, id)

  @doc """
  Gets a concept by word.
  """
  def get_concept_by_word(word) do
    Repo.get_by(Concept, word: word)
  end

  @doc """
  Creates a concept.
  """
  def create_concept(attrs \\ %{}) do
    %Concept{}
    |> Concept.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a concept.
  """
  def update_concept(%Concept{} = concept, attrs) do
    concept
    |> Concept.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the understanding level of a concept.
  """
  def update_understanding(%Concept{} = concept, level) when level >= 0 and level <= 100 do
    update_concept(concept, %{understanding: level})
  end

  @doc """
  Deletes a concept.
  """
  def delete_concept(%Concept{} = concept) do
    Repo.delete(concept)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking concept changes.
  """
  def change_concept(%Concept{} = concept, attrs \\ %{}) do
    Concept.changeset(concept, attrs)
  end

  @doc """
  Returns a MapSet of all known words for quick lookup.
  """
  def known_words do
    Concept
    |> select([c], c.word)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns a map of word -> understanding level for all known words.
  """
  def known_words_with_understanding do
    Concept
    |> select([c], {c.word, c.understanding})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns true if a word exists in vocabulary.
  """
  def word_known?(word) do
    Repo.exists?(from c in Concept, where: c.word == ^word)
  end

  @doc """
  Creates multiple concepts at once.
  """
  def create_concepts(concepts_attrs) when is_list(concepts_attrs) do
    Enum.map(concepts_attrs, fn attrs ->
      create_concept(attrs)
    end)
  end
end

defmodule Langseed.Vocabulary do
  @moduledoc """
  The Vocabulary context for managing vocabulary concepts across languages.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Vocabulary.Concept
  alias Langseed.Accounts.Scope

  @doc """
  Returns the list of concepts for a scope (user + language), sorted by understanding (descending).
  """
  @spec list_concepts(Scope.t() | nil) :: [Concept.t()]
  def list_concepts(%Scope{user: user, language: language}) do
    Concept
    |> where(user_id: ^user.id, language: ^language)
    |> order_by(desc: :understanding, asc: :word)
    |> Repo.all()
  end

  def list_concepts(nil), do: []

  @doc """
  Gets a single concept for a scope.
  Raises if not found.
  """
  @spec get_concept!(Scope.t(), term()) :: Concept.t()
  def get_concept!(%Scope{user: user}, id) do
    Concept
    |> where(user_id: ^user.id, id: ^id)
    |> Repo.one!()
  end

  def get_concept!(nil, _id), do: raise("Authentication required")

  @doc """
  Gets a concept by word for a scope.
  """
  @spec get_concept_by_word(Scope.t() | nil, String.t()) :: Concept.t() | nil
  def get_concept_by_word(%Scope{user: user, language: language}, word) do
    Repo.get_by(Concept, word: word, user_id: user.id, language: language)
  end

  def get_concept_by_word(nil, _word), do: nil

  @doc """
  Creates a concept for a scope (user + language).
  """
  @spec create_concept(Scope.t() | nil, map()) ::
          {:ok, Concept.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def create_concept(%Scope{user: user, language: language}, attrs) do
    %Concept{}
    |> Concept.changeset(attrs |> Map.put(:user_id, user.id) |> Map.put(:language, language))
    |> Repo.insert()
  end

  def create_concept(nil, _attrs), do: {:error, "Authentication required"}

  @doc """
  Marks words as already known (100% understanding) without generating explanations.
  Returns {:ok, count} with the number of words added.
  """
  @spec mark_words_as_known(Scope.t() | nil, [String.t()]) :: {:ok, integer()} | {:error, String.t()}
  def mark_words_as_known(%Scope{language: language} = scope, words) when is_list(words) do
    existing = known_words(scope)

    # Build base attrs - pinyin only for Chinese
    base_attrs = %{
      understanding: 100,
      meaning: "-",
      part_of_speech: "other",
      explanations: []
    }

    base_attrs = if language == "zh", do: Map.put(base_attrs, :pinyin, "-"), else: base_attrs

    results =
      words
      |> Enum.reject(&MapSet.member?(existing, &1))
      |> Enum.map(fn word ->
        create_concept(scope, Map.put(base_attrs, :word, word))
      end)

    added_count = Enum.count(results, &match?({:ok, _}, &1))
    {:ok, added_count}
  end

  def mark_words_as_known(nil, _words), do: {:error, "Authentication required"}

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
  Returns a MapSet of all known words for a scope (user + language).
  """
  @spec known_words(Scope.t() | nil) :: MapSet.t()
  def known_words(%Scope{user: user, language: language}) do
    Concept
    |> where(user_id: ^user.id, language: ^language)
    |> select([c], c.word)
    |> Repo.all()
    |> MapSet.new()
  end

  def known_words(nil), do: MapSet.new()

  @doc """
  Returns a map of word -> understanding level for a scope (user + language).
  """
  @spec known_words_with_understanding(Scope.t() | nil) :: %{String.t() => integer()}
  def known_words_with_understanding(%Scope{user: user, language: language}) do
    Concept
    |> where(user_id: ^user.id, language: ^language)
    |> select([c], {c.word, c.understanding})
    |> Repo.all()
    |> Map.new()
  end

  def known_words_with_understanding(nil), do: %{}

  @doc """
  Returns true if a word exists in vocabulary for a scope (user + language).
  """
  @spec word_known?(Scope.t() | nil, String.t()) :: boolean()
  def word_known?(%Scope{user: user, language: language}, word) do
    Repo.exists?(
      from c in Concept,
        where: c.word == ^word and c.user_id == ^user.id and c.language == ^language
    )
  end

  def word_known?(nil, _word), do: false

  @doc """
  Toggles the paused state of a concept.
  """
  @spec toggle_paused(Concept.t()) :: {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def toggle_paused(%Concept{} = concept) do
    update_concept(concept, %{paused: !concept.paused})
  end

  @doc """
  Pauses a concept (won't appear in practice).
  """
  @spec pause_concept(Concept.t()) :: {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def pause_concept(%Concept{} = concept) do
    update_concept(concept, %{paused: true})
  end

  @doc """
  Unpauses a concept (will appear in practice again).
  """
  @spec unpause_concept(Concept.t()) :: {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def unpause_concept(%Concept{} = concept) do
    update_concept(concept, %{paused: false})
  end
end

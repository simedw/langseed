defmodule Langseed.Vocabulary.WordImports do
  @moduledoc """
  Context for managing async word imports.
  """

  import Ecto.Query
  alias Langseed.Repo
  alias Langseed.Accounts.Scope
  alias Langseed.Vocabulary.WordImport
  alias Langseed.Workers.WordImportWorker

  @doc """
  Enqueues words for async import. Returns the list of created WordImport records.
  Broadcasts the initial queue state to the user.
  """
  def enqueue_words(%Scope{} = scope, words, context) when is_list(words) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Create import records for each word
    imports =
      words
      |> Enum.map(fn word ->
        %{
          user_id: scope.user.id,
          language: scope.language,
          word: word,
          context: context,
          status: "pending",
          inserted_at: now,
          updated_at: now
        }
      end)

    # Insert all at once
    {_count, records} = Repo.insert_all(WordImport, imports, returning: true)

    # Enqueue a worker job if not already running
    maybe_enqueue_worker(scope.user.id)

    # Broadcast queue update
    broadcast_queue_update(scope.user.id)

    {:ok, records}
  end

  @doc """
  Gets all pending imports for a user.
  """
  def pending_imports(user_id) do
    WordImport
    |> where([w], w.user_id == ^user_id and w.status in ["pending", "processing"])
    |> order_by([w], asc: w.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets the count of pending imports for a user.
  """
  def pending_count(user_id) do
    WordImport
    |> where([w], w.user_id == ^user_id and w.status in ["pending", "processing"])
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets the next pending import for processing.
  Marks it as "processing" atomically.
  Also resets any stale "processing" imports (stuck for > 5 min) back to pending.
  """
  def claim_next(user_id) do
    # First, reset any stale processing imports (stuck for > 5 minutes)
    reset_stale_processing(user_id)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    query =
      WordImport
      |> where([w], w.user_id == ^user_id and w.status == "pending")
      |> order_by([w], asc: w.inserted_at)
      |> limit(1)
      |> lock("FOR UPDATE SKIP LOCKED")

    Repo.transaction(fn ->
      case Repo.one(query) do
        nil ->
          nil

        import ->
          import
          |> Ecto.Changeset.change(status: "processing", updated_at: now)
          |> Repo.update!()
      end
    end)
  end

  # Reset imports stuck in "processing" for more than 5 minutes
  defp reset_stale_processing(user_id) do
    stale_threshold =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-5 * 60, :second)
      |> NaiveDateTime.truncate(:second)

    WordImport
    |> where([w], w.user_id == ^user_id)
    |> where([w], w.status == "processing")
    |> where([w], w.updated_at < ^stale_threshold)
    |> Repo.update_all(set: [status: "pending"])
  end

  @doc """
  Marks an import as completed and deletes it.
  """
  def complete(import_id) do
    case Repo.get(WordImport, import_id) do
      nil -> {:error, :not_found}
      import -> Repo.delete(import)
    end
  end

  @doc """
  Marks an import as failed with error message.
  """
  def fail(import_id, error) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    case Repo.get(WordImport, import_id) do
      nil ->
        {:error, :not_found}

      import ->
        import
        |> Ecto.Changeset.change(status: "failed", error: error, updated_at: now)
        |> Repo.update()
    end
  end

  @doc """
  Clears failed imports for a user.
  """
  def clear_failed(user_id) do
    WordImport
    |> where([w], w.user_id == ^user_id and w.status == "failed")
    |> Repo.delete_all()
  end

  # Enqueue worker if there isn't already one running for this user
  defp maybe_enqueue_worker(user_id) do
    # Use unique constraint to prevent duplicate jobs
    %{user_id: user_id}
    |> WordImportWorker.new(unique: [period: 60, keys: [:user_id]])
    |> Oban.insert()
  end

  @doc """
  Broadcasts queue update to all connected clients for this user.
  """
  def broadcast_queue_update(user_id) do
    count = pending_count(user_id)
    imports = pending_imports(user_id)

    processing =
      Enum.find(imports, fn i -> i.status == "processing" end)

    Phoenix.PubSub.broadcast(
      Langseed.PubSub,
      "word_imports:#{user_id}",
      {:word_import_update, %{count: count, processing: processing}}
    )
  end

  @doc """
  Subscribe to word import updates for a user.
  """
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(Langseed.PubSub, "word_imports:#{user_id}")
  end
end

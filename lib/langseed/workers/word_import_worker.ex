defmodule Langseed.Workers.WordImportWorker do
  @moduledoc """
  Oban worker that processes word imports one at a time.
  Processes all pending imports for a user, then exits.
  """

  use Oban.Worker, queue: :word_imports, max_attempts: 3

  require Logger

  alias Langseed.Repo
  alias Langseed.Accounts.User
  alias Langseed.Accounts.Scope
  alias Langseed.Vocabulary.WordImports
  alias Langseed.Services.WordImporter

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Repo.get!(User, user_id)
    process_queue(user)
    :ok
  end

  defp process_queue(user) do
    case WordImports.claim_next(user.id) do
      {:ok, nil} ->
        # No more pending imports
        WordImports.broadcast_queue_update(user.id)
        :done

      {:ok, import} ->
        process_import(user, import)
        # Continue processing next
        process_queue(user)
    end
  end

  defp process_import(user, import) do
    scope = %Scope{user: user, language: import.language}

    # Broadcast that we're processing this word
    WordImports.broadcast_queue_update(user.id)

    case WordImporter.import_single_word_sync(scope, import.word, import.context || "") do
      {:ok, _word} ->
        WordImports.complete(import.id)
        broadcast_word_added(user.id, import.word)
        Logger.info("Imported word: #{import.word} for user #{user.id}")

      {:error, reason} ->
        WordImports.fail(import.id, inspect(reason))
        Logger.warning("Failed to import word: #{import.word} - #{inspect(reason)}")
    end

    # Small delay between words to avoid hammering the LLM
    Process.sleep(100)
  end

  defp broadcast_word_added(user_id, word) do
    Phoenix.PubSub.broadcast(
      Langseed.PubSub,
      "word_imports:#{user_id}",
      {:word_imported, %{word: word}}
    )
  end
end

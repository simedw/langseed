defmodule Langseed.Workers.QuestionGenerator do
  @moduledoc """
  Background worker that pre-generates questions for words that need practice.
  Ensures each word with < 60% understanding has at least 4 unused questions ready.
  """

  use Oban.Worker, queue: :questions, max_attempts: 3

  alias Langseed.Repo
  alias Langseed.Practice
  alias Langseed.Accounts.User
  alias Langseed.Accounts.Scope

  @target_questions_per_word 4
  @supported_languages ["zh", "en", "sv"]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) when not is_nil(user_id) do
    user = Repo.get!(User, user_id)
    generate_missing_questions_for_user(user)
    :ok
  end

  def perform(%Oban.Job{}) do
    # Generate for all users
    generate_missing_questions_all_users()
    :ok
  end

  @doc """
  Generates questions for all users that have concepts needing questions.
  Called by the cron job.
  """
  def generate_missing_questions_all_users do
    User
    |> Repo.all()
    |> Enum.each(&generate_missing_questions_for_user/1)
  end

  @doc """
  Generates questions for a specific user's concepts across all languages.
  """
  def generate_missing_questions_for_user(%User{} = user) do
    # Generate for each supported language
    Enum.each(@supported_languages, fn language ->
      scope = %Scope{user: user, language: language}
      generate_missing_questions_for_scope(scope)
    end)
  end

  defp generate_missing_questions_for_scope(%Scope{} = scope) do
    Practice.get_concepts_needing_questions(scope, @target_questions_per_word)
    |> Enum.each(fn {concept, current_count} ->
      generate_questions_for_concept(scope, concept, current_count)
    end)
  end

  defp generate_questions_for_concept(scope, concept, current_count) do
    needed = @target_questions_per_word - current_count
    Enum.each(1..needed//1, fn _ -> generate_single_question(scope, concept) end)
  end

  defp generate_single_question(scope, concept) do
    # Add some delay between API calls to avoid rate limiting
    Process.sleep(500)

    case Practice.generate_question(scope, concept) do
      {:ok, _question} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to generate question for #{concept.word}: #{inspect(reason)}")
    end
  end

  @doc """
  Enqueues a job to generate questions for a specific user.
  """
  def enqueue(%User{} = user) do
    %{user_id: user.id}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Enqueues a job to generate questions for all users.
  """
  def enqueue do
    %{}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end

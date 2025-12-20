defmodule Langseed.Workers.QuestionGenerator do
  @moduledoc """
  Background worker that pre-generates questions for concepts with active SRS records.
  Ensures each concept has at least target_count unused questions per question type.
  """

  use Oban.Worker, queue: :questions, max_attempts: 3

  require Logger

  alias Langseed.Repo
  alias Langseed.Practice
  alias Langseed.Practice.ConceptSRS
  alias Langseed.Accounts.User
  alias Langseed.Accounts.Scope

  @target_questions_per_type 2
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
    # Get concepts with active SRS records (not graduated)
    Practice.get_concepts_needing_questions(scope, @target_questions_per_type)
    |> Enum.each(fn {concept, _current_count} ->
      generate_questions_for_concept(scope, concept)
    end)
  end

  defp generate_questions_for_concept(scope, concept) do
    # Get question types appropriate for this language (skip pinyin for non-Chinese)
    question_types = ConceptSRS.question_types_for_language(concept.language)
    # Only generate for types that need LLM generation (not pinyin)
    llm_question_types = Enum.filter(question_types, &(&1 != "pinyin"))

    Enum.each(llm_question_types, fn question_type ->
      current_count = Practice.count_unused_questions(concept.id, question_type)

      if current_count < @target_questions_per_type do
        generate_questions_for_type(scope, concept, question_type, current_count)
      end
    end)
  end

  defp generate_questions_for_type(scope, concept, question_type, current_count) do
    needed = @target_questions_per_type - current_count

    Enum.each(1..needed//1, fn _ ->
      case Practice.generate_question(scope, concept, question_type) do
        {:ok, _question} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to generate #{question_type} question for #{concept.word}: #{inspect(reason)}"
          )
      end
    end)
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

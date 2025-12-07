defmodule Langseed.Workers.QuestionGenerator do
  @moduledoc """
  Background worker that pre-generates questions for words that need practice.
  Ensures each word with < 60% understanding has at least 4 unused questions ready.
  """

  use Oban.Worker, queue: :questions, max_attempts: 3

  import Ecto.Query
  alias Langseed.Repo
  alias Langseed.Practice
  alias Langseed.Practice.Question
  alias Langseed.Vocabulary.Concept

  @target_questions_per_word 4

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    generate_missing_questions()
    :ok
  end

  @doc """
  Generates questions for all concepts that need them.
  Called by the cron job every 5 minutes.
  """
  def generate_missing_questions do
    concepts_needing_questions()
    |> Enum.each(&generate_questions_for_concept/1)
  end

  @doc """
  Returns concepts that have fewer than @target_questions_per_word unused questions.
  Only considers concepts with understanding between 1-60%.
  """
  def concepts_needing_questions do
    # Get count of unused questions per concept
    subquery =
      from q in Question,
        where: q.used == false,
        group_by: q.concept_id,
        select: %{concept_id: q.concept_id, count: count(q.id)}

    # Find concepts with understanding 1-60% that need more questions
    from(c in Concept,
      left_join: sq in subquery(subquery),
      on: c.id == sq.concept_id,
      where: c.understanding >= 1 and c.understanding <= 60,
      where: is_nil(sq.count) or sq.count < ^@target_questions_per_word,
      select: {c, coalesce(sq.count, 0)}
    )
    |> Repo.all()
  end

  defp generate_questions_for_concept({concept, current_count}) do
    needed = @target_questions_per_word - current_count

    if needed > 0 do
      Enum.each(1..needed, fn _ ->
        # Add some delay between API calls to avoid rate limiting
        Process.sleep(500)

        case Practice.generate_question(concept) do
          {:ok, _question} ->
            :ok

          {:error, reason} ->
            # Log but don't fail the job
            require Logger
            Logger.warning("Failed to generate question for #{concept.word}: #{inspect(reason)}")
        end
      end)
    end
  end

  @doc """
  Enqueues a job to generate questions immediately.
  Useful when new words are added.
  """
  def enqueue do
    %{}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end

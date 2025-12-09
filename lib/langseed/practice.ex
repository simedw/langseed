defmodule Langseed.Practice do
  @moduledoc """
  The Practice context for managing vocabulary practice sessions.
  Designed to be easily integrated with Oban for background question generation.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Practice.Question
  alias Langseed.Vocabulary
  alias Langseed.Vocabulary.Concept
  alias Langseed.LLM
  alias Langseed.Accounts.Scope

  @doc """
  Gets the next word to practice for a scope, prioritizing lowest understanding (0-60%).
  Returns nil if no words need practice.
  """
  @spec get_next_concept(Scope.t() | nil) :: Concept.t() | nil
  def get_next_concept(%Scope{user: user, language: language}) do
    Concept
    |> where([c], c.user_id == ^user.id and c.language == ^language)
    |> where([c], c.understanding >= 0 and c.understanding <= 60)
    |> where([c], c.paused == false)
    |> order_by([c], asc: c.understanding)
    |> limit(1)
    |> Repo.one()
  end

  def get_next_concept(nil), do: nil

  @doc """
  Gets all concepts that need practice for a scope (0-60% understanding).
  """
  @spec get_practice_concepts(Scope.t() | nil, integer()) :: [Concept.t()]
  def get_practice_concepts(scope, limit \\ 10)

  def get_practice_concepts(%Scope{user: user, language: language}, limit) do
    Concept
    |> where([c], c.user_id == ^user.id and c.language == ^language)
    |> where([c], c.understanding >= 0 and c.understanding <= 60)
    |> where([c], c.paused == false)
    |> order_by([c], asc: c.understanding)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_practice_concepts(nil, _limit), do: []

  @doc """
  Gets concepts suitable for quiz questions (1-60% understanding).
  """
  @spec get_quiz_concepts(Scope.t() | nil) :: [Concept.t()]
  def get_quiz_concepts(%Scope{user: user, language: language}) do
    Concept
    |> where([c], c.user_id == ^user.id and c.language == ^language)
    |> where([c], c.understanding >= 1 and c.understanding <= 60)
    |> where([c], c.paused == false)
    |> order_by([c], asc: c.understanding)
    |> Repo.all()
  end

  def get_quiz_concepts(nil), do: []

  @doc """
  Gets an unused question for a concept, or generates one if none exists.
  """
  @spec get_or_generate_question(Scope.t() | nil, Concept.t()) ::
          {:ok, Question.t()} | {:error, String.t()}
  def get_or_generate_question(%Scope{} = scope, concept) do
    case get_unused_question(concept.id) do
      nil -> generate_question(scope, concept)
      question -> {:ok, question}
    end
  end

  def get_or_generate_question(nil, _concept), do: {:error, "Authentication required"}

  @doc """
  Gets an unused question for a concept.
  """
  @spec get_unused_question(term()) :: Question.t() | nil
  def get_unused_question(concept_id) do
    Question
    |> where([q], q.concept_id == ^concept_id and q.used == false)
    |> order_by([q], asc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Generates a question for a concept and stores it in the database.
  Randomly picks between yes_no and fill_blank question types.
  """
  @spec generate_question(Scope.t() | nil, Concept.t()) ::
          {:ok, Question.t()} | {:error, String.t()}
  def generate_question(%Scope{} = scope, concept) do
    known_words = Vocabulary.known_words(scope)
    question_type = Enum.random(["yes_no", "fill_blank"])

    case question_type do
      "yes_no" -> generate_yes_no(scope, concept, known_words)
      "fill_blank" -> generate_fill_blank(scope, concept, known_words)
    end
  end

  def generate_question(nil, _concept), do: {:error, "Authentication required"}

  defp generate_yes_no(%Scope{user: user, language: language}, concept, known_words) do
    case LLM.generate_yes_no_question(user.id, concept, known_words, language) do
      {:ok, data} ->
        attrs = %{
          concept_id: concept.id,
          question_type: "yes_no",
          question_text: data.question,
          correct_answer: if(data.answer, do: "yes", else: "no"),
          explanation: data.explanation
        }

        attrs = Map.put(attrs, :user_id, user.id)

        create_question(attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_fill_blank(%Scope{user: user, language: language}, concept, known_words) do
    # Get distractor words (other concepts from the same user and language)
    base_query = Concept |> where([c], c.user_id == ^user.id and c.language == ^language)

    distractors =
      base_query
      |> where([c], c.id != ^concept.id and c.part_of_speech == ^concept.part_of_speech)
      |> order_by(fragment("RANDOM()"))
      |> limit(5)
      |> Repo.all()

    # Fallback to any words if not enough same POS
    distractors =
      if length(distractors) < 3 do
        base_query
        |> where([c], c.id != ^concept.id)
        |> order_by(fragment("RANDOM()"))
        |> limit(5)
        |> Repo.all()
      else
        distractors
      end

    case LLM.generate_fill_blank_question(user.id, concept, known_words, distractors, language) do
      {:ok, data} ->
        attrs = %{
          concept_id: concept.id,
          question_type: "fill_blank",
          question_text: data.sentence,
          correct_answer: Integer.to_string(data.correct_index),
          options: data.options
        }

        attrs = Map.put(attrs, :user_id, user.id)

        create_question(attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a question.
  """
  @spec create_question(map()) :: {:ok, Question.t()} | {:error, Ecto.Changeset.t()}
  def create_question(attrs) do
    %Question{}
    |> Question.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Marks a question as used.
  """
  @spec mark_question_used(Question.t()) :: {:ok, Question.t()} | {:error, Ecto.Changeset.t()}
  def mark_question_used(question) do
    question
    |> Question.changeset(%{used: true})
    |> Repo.update()
  end

  @doc """
  Records an answer and updates the concept's understanding score.
  """
  @spec record_answer(Concept.t(), boolean()) ::
          {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def record_answer(concept, correct?) do
    change =
      if correct? do
        # Correct: +10-15%
        Enum.random(10..15)
      else
        # Wrong: -5% (min stays at 1%)
        -5
      end

    new_understanding =
      (concept.understanding + change)
      |> max(1)
      |> min(100)

    Vocabulary.update_concept(concept, %{understanding: new_understanding})
  end

  @doc """
  Sets a 0% understanding word to 1% (user said they understand).
  """
  @spec mark_understood(Concept.t()) :: {:ok, Concept.t()} | {:error, Ecto.Changeset.t()}
  def mark_understood(concept) do
    if concept.understanding == 0 do
      Vocabulary.update_concept(concept, %{understanding: 1})
    else
      {:ok, concept}
    end
  end

  @doc """
  Evaluates a user's sentence using the target word.
  """
  @spec evaluate_sentence(Scope.t() | nil, Concept.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def evaluate_sentence(%Scope{user: user, language: language} = scope, concept, user_sentence) do
    known_words = Vocabulary.known_words(scope)
    LLM.evaluate_sentence(user.id, concept, user_sentence, known_words, language)
  end

  def evaluate_sentence(nil, _concept, _user_sentence), do: {:error, "Authentication required"}

  @doc """
  Regenerates explanations for a concept.
  """
  @spec regenerate_explanation(Scope.t() | nil, Concept.t()) ::
          {:ok, Concept.t()} | {:error, String.t()}
  def regenerate_explanation(%Scope{user: user} = scope, concept) do
    known_words = Vocabulary.known_words(scope)

    case LLM.regenerate_explanation(user.id, concept, known_words) do
      {:ok, new_explanations} ->
        Vocabulary.update_concept(concept, %{explanations: new_explanations})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def regenerate_explanation(nil, _concept), do: {:error, "Authentication required"}

  @doc """
  Counts unused questions for a concept.
  """
  @spec count_unused_questions(term()) :: integer()
  def count_unused_questions(concept_id) do
    Question
    |> where([q], q.concept_id == ^concept_id and q.used == false)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets concepts needing more questions for a scope.
  Returns concepts with understanding 1-60% that have fewer than target_count unused questions.
  """
  @spec get_concepts_needing_questions(Scope.t() | nil, integer()) :: [{Concept.t(), integer()}]
  def get_concepts_needing_questions(%Scope{user: user, language: language}, target_count) do
    subquery =
      from q in Question,
        where: q.used == false,
        group_by: q.concept_id,
        select: %{concept_id: q.concept_id, count: count(q.id)}

    Concept
    |> where([c], c.user_id == ^user.id and c.language == ^language)
    |> where([c], c.understanding >= 1 and c.understanding <= 60)
    |> where([c], c.paused == false)
    |> join(:left, [c], q in subquery(subquery), on: c.id == q.concept_id)
    |> where([c, q], is_nil(q.count) or q.count < ^target_count)
    |> select([c, q], {c, coalesce(q.count, 0)})
    |> Repo.all()
  end

  def get_concepts_needing_questions(nil, _target_count), do: []
end

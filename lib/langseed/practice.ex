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
  alias Langseed.Accounts.User

  @doc """
  Gets the next word to practice for a user, prioritizing lowest understanding (0-60%).
  Returns nil if no words need practice.
  """
  def get_next_concept(%User{} = user) do
    Concept
    |> where([c], c.user_id == ^user.id)
    |> where([c], c.understanding >= 0 and c.understanding <= 60)
    |> order_by([c], asc: c.understanding)
    |> limit(1)
    |> Repo.one()
  end

  def get_next_concept(nil), do: nil

  @doc """
  Gets all concepts that need practice for a user (0-60% understanding).
  """
  def get_practice_concepts(user, limit \\ 10)

  def get_practice_concepts(%User{} = user, limit) do
    Concept
    |> where([c], c.user_id == ^user.id)
    |> where([c], c.understanding >= 0 and c.understanding <= 60)
    |> order_by([c], asc: c.understanding)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_practice_concepts(nil, _limit), do: []

  @doc """
  Gets concepts suitable for quiz questions (1-60% understanding).
  """
  def get_quiz_concepts(%User{} = user) do
    Concept
    |> where([c], c.user_id == ^user.id)
    |> where([c], c.understanding >= 1 and c.understanding <= 60)
    |> order_by([c], asc: c.understanding)
    |> Repo.all()
  end

  def get_quiz_concepts(nil), do: []

  @doc """
  Gets an unused question for a concept, or generates one if none exists.
  """
  def get_or_generate_question(%User{} = user, concept) do
    case get_unused_question(concept.id) do
      nil -> generate_question(user, concept)
      question -> {:ok, question}
    end
  end

  def get_or_generate_question(nil, _concept), do: {:error, "Authentication required"}

  @doc """
  Gets an unused question for a concept.
  """
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
  def generate_question(%User{} = user, concept) do
    known_words = Vocabulary.known_words(user)
    question_type = Enum.random(["yes_no", "fill_blank"])

    case question_type do
      "yes_no" -> generate_yes_no(user, concept, known_words)
      "fill_blank" -> generate_fill_blank(user, concept, known_words)
    end
  end

  def generate_question(nil, _concept), do: {:error, "Authentication required"}

  defp generate_yes_no(user, concept, known_words) do
    case LLM.generate_yes_no_question(concept, known_words) do
      {:ok, data} ->
        attrs = %{
          concept_id: concept.id,
          question_type: "yes_no",
          question_text: data.question,
          correct_answer: if(data.answer, do: "yes", else: "no"),
          explanation: data.explanation
        }

        attrs = if user, do: Map.put(attrs, :user_id, user.id), else: attrs

        create_question(attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_fill_blank(user, concept, known_words) do
    # Get some distractor words (other concepts) - scoped by user if available
    base_query =
      if user do
        Concept |> where([c], c.user_id == ^user.id)
      else
        Concept
      end

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

    case LLM.generate_fill_blank_question(concept, known_words, distractors) do
      {:ok, data} ->
        attrs = %{
          concept_id: concept.id,
          question_type: "fill_blank",
          question_text: data.sentence,
          correct_answer: Integer.to_string(data.correct_index),
          options: data.options
        }

        attrs = if user, do: Map.put(attrs, :user_id, user.id), else: attrs

        create_question(attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a question.
  """
  def create_question(attrs) do
    %Question{}
    |> Question.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Marks a question as used.
  """
  def mark_question_used(question) do
    question
    |> Question.changeset(%{used: true})
    |> Repo.update()
  end

  @doc """
  Records an answer and updates the concept's understanding score.
  """
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
  def evaluate_sentence(%User{} = user, concept, user_sentence) do
    known_words = Vocabulary.known_words(user)
    LLM.evaluate_sentence(concept, user_sentence, known_words)
  end

  def evaluate_sentence(nil, _concept, _user_sentence), do: {:error, "Authentication required"}

  @doc """
  Regenerates explanations for a concept.
  """
  def regenerate_explanation(%User{} = user, concept) do
    known_words = Vocabulary.known_words(user)

    case LLM.regenerate_explanation(concept, known_words) do
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
  def count_unused_questions(concept_id) do
    Question
    |> where([q], q.concept_id == ^concept_id and q.used == false)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets concepts needing more questions for a user.
  Returns concepts with understanding 1-60% that have fewer than target_count unused questions.
  """
  def get_concepts_needing_questions(%User{} = user, target_count) do
    subquery =
      from q in Question,
        where: q.used == false,
        group_by: q.concept_id,
        select: %{concept_id: q.concept_id, count: count(q.id)}

    Concept
    |> where([c], c.user_id == ^user.id)
    |> where([c], c.understanding >= 1 and c.understanding <= 60)
    |> join(:left, [c], q in subquery(subquery), on: c.id == q.concept_id)
    |> where([c, q], is_nil(q.count) or q.count < ^target_count)
    |> select([c, q], {c, coalesce(q.count, 0)})
    |> Repo.all()
  end

  def get_concepts_needing_questions(nil, _target_count), do: []
end

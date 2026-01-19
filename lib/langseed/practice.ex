defmodule Langseed.Practice do
  @moduledoc """
  The Practice context for managing vocabulary practice sessions.
  Uses a tier-based SRS (Spaced Repetition System) with independent tracking
  for each question type (pinyin, yes_no, multiple_choice).
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Practice.Question
  alias Langseed.Practice.ConceptSRS
  alias Langseed.Vocabulary
  alias Langseed.Vocabulary.Concept
  alias Langseed.LLM
  alias Langseed.Accounts.Scope

  @session_new_limit 20
  @questions_without_pregeneration ["pinyin"]
  # ============================================================================
  # NEW SRS-BASED PRACTICE FLOW
  # ============================================================================

  @doc """
  Gets the next practice item for a scope.

  Returns:
  - `{:definition, concept}` - New word needs definition shown
  - `{:srs, srs_record}` - Due SRS review with preloaded concept
  - `nil` - Nothing to practice

  Options:
  - `:last_concept_id` - Avoid showing this concept again (cooldown)
  - `:session_new_count` - Number of new words shown this session
  """
  def get_next_practice(scope, opts \\ [])

  def get_next_practice(%Scope{} = scope, opts) do
    last_concept_id = Keyword.get(opts, :last_concept_id)
    session_new_count = Keyword.get(opts, :session_new_count, 0)

    # Priority 1: Due SRS reviews (always prioritize reviews)
    case get_next_srs_review(scope, last_concept_id) do
      nil ->
        get_next_new_definition(scope, session_new_count)

      srs_record ->
        {:srs, srs_record}
    end
  end

  def get_next_practice(nil, _opts), do: nil

  defp get_next_new_definition(scope, session_new_count) do
    # Priority 2: New definitions (if under session limit)
    if session_new_count < @session_new_limit do
      case get_concept_needing_definition(scope) do
        nil -> nil
        concept -> {:definition, concept}
      end
    else
      nil
    end
  end

  @doc """
  Finds concepts with no SRS records (not seen definition yet).
  """
  def get_concept_needing_definition(%Scope{user: user, language: language}) do
    from(c in Concept,
      left_join: srs in ConceptSRS,
      on: srs.concept_id == c.id and srs.user_id == ^user.id,
      where: c.user_id == ^user.id,
      where: c.language == ^language,
      where: c.paused == false,
      where: is_nil(srs.id),
      order_by: [asc: c.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_concept_needing_definition(nil), do: nil

  defp get_next_srs_review(%Scope{user: user, language: language}, last_concept_id) do
    now = DateTime.utc_now()

    base_query =
      from(srs in ConceptSRS,
        as: :srs,
        join: c in Concept,
        on: srs.concept_id == c.id,
        where: srs.user_id == ^user.id,
        where: c.language == ^language,
        where: c.paused == false,
        where: srs.tier < 7,
        where: srs.next_review <= ^now,
        preload: [concept: c]
      )

    # Try to get due item excluding last_concept_id (cooldown)
    cooldown_query =
      if last_concept_id do
        base_query |> where([srs, c], c.id != ^last_concept_id)
      else
        base_query
      end

    # Priority 1: SRS with pre-generated questions
    srs_with_question =
      cooldown_query
      |> where(
        [srs],
        srs.question_type in @questions_without_pregeneration or
          exists(
            from(q in Question,
              where: q.concept_id == parent_as(:srs).concept_id,
              where: q.question_type == parent_as(:srs).question_type,
              where: q.user_id == ^user.id,
              where: is_nil(q.used_at)
            )
          )
      )
      |> order_by([srs], asc: srs.next_review)
      |> limit(1)
      |> Repo.one()

    # Priority 2: Any due SRS from cooldown set
    # Priority 3: Allow same concept if cooldown blocked everything
    srs_with_question ||
      cooldown_query |> order_by([srs], asc: srs.next_review) |> limit(1) |> Repo.one() ||
      if last_concept_id do
        base_query |> order_by([srs], asc: srs.next_review) |> limit(1) |> Repo.one()
      else
        nil
      end
  end

  @doc """
  Initializes SRS records for a concept when user clicks "Understand".
  Creates one record per question type based on language.
  """
  def initialize_srs_for_concept(%Concept{} = concept, user_id) do
    question_types = ConceptSRS.question_types_for_language(concept.language)
    now = DateTime.utc_now()

    Enum.each(question_types, fn type ->
      %ConceptSRS{}
      |> ConceptSRS.changeset(%{
        concept_id: concept.id,
        user_id: user_id,
        question_type: type,
        tier: 0,
        next_review: now
      })
      |> Repo.insert!()
    end)

    # Update concept understanding to reflect SRS state
    update_concept_understanding(concept, user_id)

    # Broadcast practice state change
    broadcast_practice_updated(user_id, concept.language)
  end

  @doc """
  Records an SRS answer and updates the tier/next_review.
  """
  def record_srs_answer(%ConceptSRS{} = srs_record, correct?) do
    new_tier = ConceptSRS.update_tier(srs_record.tier, correct?)
    next_review = ConceptSRS.calculate_next_review(new_tier)
    streak_lapses = ConceptSRS.update_streak_and_lapses(srs_record, correct?)

    attrs =
      Map.merge(streak_lapses, %{
        tier: new_tier,
        next_review: next_review
      })

    result =
      srs_record
      |> ConceptSRS.changeset(attrs)
      |> Repo.update()

    # Update cached understanding on concept
    case result do
      {:ok, updated_srs} ->
        update_concept_understanding_by_id(updated_srs.concept_id, updated_srs.user_id)

        # Broadcast practice state change
        # Get language from concept (either preloaded or fetch it)
        language =
          case srs_record.concept do
            %Ecto.Association.NotLoaded{} ->
              Repo.get!(Concept, updated_srs.concept_id).language

            concept ->
              concept.language
          end

        broadcast_practice_updated(updated_srs.user_id, language)

        {:ok, updated_srs}

      error ->
        error
    end
  end

  @doc """
  Checks if there are practice items ready (for notification indicator).
  Shows indicator when ANY SRS items are due (even without pre-generated questions).
  """
  def has_practice_ready?(%Scope{user: user, language: language}) do
    now = DateTime.utc_now()

    # Check for any due SRS records
    due_srs =
      from(srs in ConceptSRS,
        join: c in Concept,
        on: srs.concept_id == c.id,
        where: srs.user_id == ^user.id,
        where: c.language == ^language,
        where: c.paused == false,
        where: srs.tier < 7,
        where: srs.next_review <= ^now,
        limit: 1
      )
      |> Repo.exists?()

    if due_srs do
      true
    else
      # Check for new definitions
      from(c in Concept,
        left_join: srs in ConceptSRS,
        on: srs.concept_id == c.id and srs.user_id == ^user.id,
        where: c.user_id == ^user.id,
        where: c.language == ^language,
        where: c.paused == false,
        where: is_nil(srs.id),
        limit: 1
      )
      |> Repo.exists?()
    end
  end

  def has_practice_ready?(nil), do: false

  @doc """
  Calculates and updates the cached understanding for a concept.
  """
  def update_concept_understanding(%Concept{} = concept, user_id) do
    update_concept_understanding_by_id(concept.id, user_id)
  end

  defp update_concept_understanding_by_id(concept_id, user_id) do
    avg_tier =
      from(s in ConceptSRS,
        where: s.concept_id == ^concept_id,
        where: s.user_id == ^user_id,
        select: avg(s.tier)
      )
      |> Repo.one()

    new_understanding =
      case avg_tier do
        nil -> 0
        %Decimal{} = avg -> avg |> Decimal.to_float() |> Kernel./(7) |> Kernel.*(100) |> round()
        avg when is_number(avg) -> round(avg / 7 * 100)
      end

    from(c in Concept, where: c.id == ^concept_id)
    |> Repo.update_all(set: [understanding: new_understanding])
  end

  @doc """
  Gets all SRS records for a concept (for progress display).
  """
  def get_srs_records_for_concept(concept_id, user_id) do
    from(s in ConceptSRS,
      where: s.concept_id == ^concept_id,
      where: s.user_id == ^user_id,
      order_by: [asc: s.question_type]
    )
    |> Repo.all()
  end

  # ============================================================================
  # LEGACY FUNCTIONS (kept for backwards compatibility)
  # ============================================================================

  @doc """
  Gets the next word to practice for a scope, prioritizing lowest understanding (0-60%).
  Returns nil if no words need practice.

  DEPRECATED: Use get_next_practice/2 instead.
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
    |> where([q], q.concept_id == ^concept_id and is_nil(q.used_at))
    |> order_by([q], asc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets an unused question for a concept and specific question type.
  """
  def get_unused_question(concept_id, question_type) do
    Question
    |> where(
      [q],
      q.concept_id == ^concept_id and q.question_type == ^question_type and is_nil(q.used_at)
    )
    |> order_by([q], asc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Generates a question for a concept and stores it in the database.
  Randomly picks between yes_no and multiple_choice question types.
  Also triggers async audio pre-generation if caching is available.
  """
  @spec generate_question(Scope.t() | nil, Concept.t()) ::
          {:ok, Question.t()} | {:error, String.t()}
  def generate_question(%Scope{} = scope, concept) do
    known_words = Vocabulary.known_words(scope)
    question_type = Enum.random(["yes_no", "multiple_choice"])

    result =
      case question_type do
        "yes_no" -> generate_yes_no(scope, concept, known_words)
        "multiple_choice" -> generate_multiple_choice(scope, concept, known_words)
      end

    # Pre-generate audio async (non-blocking)
    with {:ok, question} <- result do
      pre_generate_audio_async(question, concept.language)
      {:ok, question}
    end
  end

  def generate_question(nil, _concept), do: {:error, "Authentication required"}

  @doc """
  Generates a question for a concept with a specific question type.
  Also triggers async audio pre-generation if caching is available.
  """
  @spec generate_question(Scope.t() | nil, Concept.t(), String.t()) ::
          {:ok, Question.t()} | {:error, String.t()}
  def generate_question(%Scope{} = scope, concept, question_type) do
    known_words = Vocabulary.known_words(scope)

    result =
      case question_type do
        "yes_no" -> generate_yes_no(scope, concept, known_words)
        "multiple_choice" -> generate_multiple_choice(scope, concept, known_words)
        _ -> {:error, "Unknown question type: #{question_type}"}
      end

    # Pre-generate audio async (non-blocking)
    with {:ok, question} <- result do
      pre_generate_audio_async(question, concept.language)
      {:ok, question}
    end
  end

  def generate_question(nil, _concept, _type), do: {:error, "Authentication required"}

  @doc """
  Pre-generates audio for a question asynchronously.
  Runs in background via TaskSupervisor with 3 retries on failure.
  """
  def pre_generate_audio_async(question, language) do
    require Logger

    if Langseed.Audio.cache_available?() do
      Logger.info("Pre-generating audio for question #{question.id} (#{language})")

      Task.Supervisor.start_child(Langseed.TaskSupervisor, fn ->
        sentence = Langseed.Practice.QuestionAudio.sentence_for_question(question)
        generate_audio_with_retry(question.id, sentence, language, 3)
      end)
    else
      Logger.debug("Skipping audio pre-generation (cache not available)")
    end
  end

  defp generate_audio_with_retry(question_id, sentence, language, retries_left) do
    require Logger

    case Langseed.Audio.generate_sentence_audio(sentence, language) do
      {:ok, url} when not is_nil(url) ->
        Logger.info("✓ Pre-cached audio for question #{question_id}")
        {:ok, url}

      {:ok, nil} ->
        Logger.warning("No TTS for question #{question_id} (#{language})")
        {:ok, nil}

      {:error, reason} when retries_left > 0 ->
        Logger.warning(
          "Audio generation failed for question #{question_id}, retrying (#{retries_left} left): #{inspect(reason)}"
        )

        Process.sleep(1_000)
        generate_audio_with_retry(question_id, sentence, language, retries_left - 1)

      {:error, reason} ->
        Logger.error(
          "Failed to pre-cache audio for question #{question_id} after retries: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

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

  defp generate_multiple_choice(%Scope{user: user, language: language}, concept, known_words) do
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
          question_type: "multiple_choice",
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
  Marks a question as used with a timestamp.
  """
  @spec mark_question_used(Question.t()) :: {:ok, Question.t()} | {:error, Ecto.Changeset.t()}
  def mark_question_used(question) do
    question
    |> Question.changeset(%{used: true, used_at: DateTime.utc_now()})
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
    |> where([q], q.concept_id == ^concept_id and is_nil(q.used_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts unused questions for a concept and specific question type.
  """
  def count_unused_questions(concept_id, question_type) do
    Question
    |> where(
      [q],
      q.concept_id == ^concept_id and q.question_type == ^question_type and is_nil(q.used_at)
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets concepts needing more questions for a scope.
  Returns concepts with SRS records that have fewer than target_count unused questions.
  """
  @spec get_concepts_needing_questions(Scope.t() | nil, integer()) :: [{Concept.t(), integer()}]
  def get_concepts_needing_questions(%Scope{user: user, language: language}, target_count) do
    subquery =
      from q in Question,
        where: is_nil(q.used_at),
        group_by: q.concept_id,
        select: %{concept_id: q.concept_id, count: count(q.id)}

    # Get concepts with SRS records (have been through definition stage)
    from(c in Concept,
      join: srs in ConceptSRS,
      on: srs.concept_id == c.id,
      where: c.user_id == ^user.id and c.language == ^language,
      where: srs.tier < 7,
      where: c.paused == false,
      left_join: q in subquery(subquery),
      on: c.id == q.concept_id,
      where: is_nil(q.count) or q.count < ^target_count,
      distinct: c.id,
      select: {c, coalesce(q.count, 0)}
    )
    |> Repo.all()
  end

  def get_concepts_needing_questions(nil, _target_count), do: []

  @doc """
  Creates SRS records at tier 7 (graduated) for seed/known words.
  """
  def create_graduated_srs_for_concept(%Concept{} = concept, user_id) do
    question_types = ConceptSRS.question_types_for_language(concept.language)

    Enum.each(question_types, fn type ->
      %ConceptSRS{}
      |> ConceptSRS.changeset(%{
        concept_id: concept.id,
        user_id: user_id,
        question_type: type,
        tier: 7,
        next_review: nil
      })
      |> Repo.insert!()
    end)
  end

  # ============================================================================
  # PUBSUB BROADCASTING
  # ============================================================================

  defp broadcast_practice_updated(user_id, language) do
    Phoenix.PubSub.broadcast(
      Langseed.PubSub,
      "practice:#{user_id}:#{language}",
      {:practice_updated, %{}}
    )
  end
end

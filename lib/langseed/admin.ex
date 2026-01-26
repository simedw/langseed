defmodule Langseed.Admin do
  @moduledoc """
  Admin context for dashboard analytics and metrics.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Accounts.User
  alias Langseed.Vocabulary.Concept
  alias Langseed.Practice.{ConceptSRS, Question}
  alias Langseed.Analytics.LlmQuery

  # ============================================================================
  # USER METRICS
  # ============================================================================

  @doc """
  Returns total user count.
  """
  def total_users do
    Repo.aggregate(User, :count)
  end

  @doc """
  Returns user signups grouped by date for the last N days.
  Returns list of %{date: Date.t(), count: integer()}.
  """
  def signups_by_day(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(u in User,
      where: u.inserted_at >= ^cutoff,
      group_by: fragment("DATE(?)", u.inserted_at),
      select: %{
        date: fragment("DATE(?)", u.inserted_at),
        count: count(u.id)
      },
      order_by: [asc: fragment("DATE(?)", u.inserted_at)]
    )
    |> Repo.all()
  end

  @doc """
  Returns all users with activity metrics.
  Includes: last_activity, word_count, practice_count.
  """
  def users_with_metrics do
    # Subquery for word counts per user
    word_counts =
      from(c in Concept,
        group_by: c.user_id,
        select: %{user_id: c.user_id, word_count: count(c.id)}
      )

    # Subquery for last practice activity (most recent SRS update)
    last_activity =
      from(s in ConceptSRS,
        group_by: s.user_id,
        select: %{user_id: s.user_id, last_activity: max(s.updated_at)}
      )

    # Subquery for total practice count (questions answered)
    practice_counts =
      from(q in Question,
        where: not is_nil(q.used_at),
        group_by: q.user_id,
        select: %{user_id: q.user_id, practice_count: count(q.id)}
      )

    from(u in User,
      left_join: wc in subquery(word_counts),
      on: wc.user_id == u.id,
      left_join: la in subquery(last_activity),
      on: la.user_id == u.id,
      left_join: pc in subquery(practice_counts),
      on: pc.user_id == u.id,
      select: %{
        id: u.id,
        email: u.email,
        name: u.name,
        language: u.selected_language,
        signed_up: u.inserted_at,
        last_activity: la.last_activity,
        word_count: coalesce(wc.word_count, 0),
        practice_count: coalesce(pc.practice_count, 0)
      },
      order_by: [desc: u.inserted_at]
    )
    |> Repo.all()
  end

  # ============================================================================
  # PRACTICE METRICS
  # ============================================================================

  @doc """
  Returns practice frequency: questions answered per day for last N days.
  """
  def practice_by_day(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(q in Question,
      where: q.used_at >= ^cutoff and not is_nil(q.used_at),
      group_by: fragment("DATE(?)", q.used_at),
      select: %{
        date: fragment("DATE(?)", q.used_at),
        count: count(q.id)
      },
      order_by: [asc: fragment("DATE(?)", q.used_at)]
    )
    |> Repo.all()
  end

  @doc """
  Returns total questions answered across all users.
  """
  def total_questions_answered do
    from(q in Question, where: not is_nil(q.used_at))
    |> Repo.aggregate(:count)
  end

  # ============================================================================
  # VOCABULARY METRICS
  # ============================================================================

  @doc """
  Returns total words learned across all users.
  """
  def total_words_learned do
    Repo.aggregate(Concept, :count)
  end

  @doc """
  Returns words added per day for last N days.
  """
  def words_by_day(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(c in Concept,
      where: c.inserted_at >= ^cutoff,
      group_by: fragment("DATE(?)", c.inserted_at),
      select: %{
        date: fragment("DATE(?)", c.inserted_at),
        count: count(c.id)
      },
      order_by: [asc: fragment("DATE(?)", c.inserted_at)]
    )
    |> Repo.all()
  end

  @doc """
  Returns language distribution across all users.
  """
  def language_distribution do
    from(c in Concept,
      group_by: c.language,
      select: %{language: c.language, count: count(c.id)},
      order_by: [desc: count(c.id)]
    )
    |> Repo.all()
  end

  # ============================================================================
  # SRS METRICS
  # ============================================================================

  @doc """
  Returns average understanding level across all concepts.
  """
  def average_understanding do
    from(c in Concept, select: avg(c.understanding))
    |> Repo.one()
    |> case do
      nil -> 0
      %Decimal{} = d -> Decimal.to_float(d) |> round()
      n when is_float(n) -> round(n)
      n -> n
    end
  end

  @doc """
  Returns SRS tier distribution (how many SRS records at each tier).
  """
  def srs_tier_distribution do
    from(s in ConceptSRS,
      group_by: s.tier,
      select: %{tier: s.tier, count: count(s.id)},
      order_by: [asc: s.tier]
    )
    |> Repo.all()
  end

  # ============================================================================
  # LLM USAGE METRICS
  # ============================================================================

  @doc """
  Returns total LLM token usage.
  """
  def total_llm_usage do
    result =
      from(l in LlmQuery,
        select: %{
          input_tokens: sum(l.input_tokens),
          output_tokens: sum(l.output_tokens),
          query_count: count(l.id)
        }
      )
      |> Repo.one()

    %{
      input_tokens: result.input_tokens || 0,
      output_tokens: result.output_tokens || 0,
      query_count: result.query_count || 0
    }
  end

  @doc """
  Returns LLM usage by query type.
  """
  def llm_usage_by_type do
    from(l in LlmQuery,
      group_by: l.query_type,
      select: %{
        query_type: l.query_type,
        input_tokens: sum(l.input_tokens),
        output_tokens: sum(l.output_tokens),
        count: count(l.id)
      },
      order_by: [desc: count(l.id)]
    )
    |> Repo.all()
  end

  @doc """
  Returns LLM queries per day for last N days.
  """
  def llm_queries_by_day(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(l in LlmQuery,
      where: l.inserted_at >= ^cutoff,
      group_by: fragment("DATE(?)", l.inserted_at),
      select: %{
        date: fragment("DATE(?)", l.inserted_at),
        count: count(l.id),
        tokens: sum(l.input_tokens) + sum(l.output_tokens)
      },
      order_by: [asc: fragment("DATE(?)", l.inserted_at)]
    )
    |> Repo.all()
  end
end

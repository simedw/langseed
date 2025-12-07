defmodule Langseed.Analytics do
  @moduledoc """
  Context for tracking LLM usage and analytics.
  """

  import Ecto.Query, warn: false
  alias Langseed.Repo
  alias Langseed.Analytics.LlmQuery

  @doc """
  Logs an LLM query to the database.
  """
  def log_query(attrs) do
    %LlmQuery{}
    |> LlmQuery.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets total token usage for a user.
  """
  def get_user_usage(user_id) do
    LlmQuery
    |> where(user_id: ^user_id)
    |> select([q], %{
      total_input_tokens: sum(q.input_tokens),
      total_output_tokens: sum(q.output_tokens),
      query_count: count(q.id)
    })
    |> Repo.one()
  end

  @doc """
  Gets token usage by query type for a user.
  """
  def get_usage_by_type(user_id) do
    LlmQuery
    |> where(user_id: ^user_id)
    |> group_by([q], q.query_type)
    |> select([q], %{
      query_type: q.query_type,
      input_tokens: sum(q.input_tokens),
      output_tokens: sum(q.output_tokens),
      count: count(q.id)
    })
    |> Repo.all()
  end

  @doc """
  Gets total usage across all users (for admin).
  """
  def get_total_usage do
    LlmQuery
    |> select([q], %{
      total_input_tokens: sum(q.input_tokens),
      total_output_tokens: sum(q.output_tokens),
      query_count: count(q.id)
    })
    |> Repo.one()
  end
end

defmodule Langseed.TimeFormatter do
  @moduledoc """
  Formats datetime values as human-readable relative times.
  """

  use Gettext, backend: LangseedWeb.Gettext

  @doc """
  Formats a datetime as a relative time string.

  ## Examples

      iex> format_relative(~U[2024-01-01 12:00:00Z], ~U[2024-01-01 12:00:30Z])
      "now"

      iex> format_relative(~U[2024-01-01 12:05:00Z], ~U[2024-01-01 12:00:00Z])
      "in 5 min"

      iex> format_relative(~U[2024-01-01 11:00:00Z], ~U[2024-01-01 12:00:00Z])
      "1 hour ago"
  """
  @spec format_relative(DateTime.t() | nil, DateTime.t()) :: String.t()
  def format_relative(nil, _now), do: gettext("graduated")

  def format_relative(datetime, now) do
    diff_seconds = DateTime.diff(datetime, now, :second)

    if diff_seconds <= 60 do
      gettext("now")
    else
      format_future(diff_seconds)
    end
  end

  @doc """
  Formats a datetime relative to the current time.
  """
  @spec format_relative(DateTime.t() | nil) :: String.t()
  def format_relative(datetime) do
    format_relative(datetime, DateTime.utc_now())
  end

  defp format_future(seconds) do
    cond do
      seconds < 3600 ->
        minutes = div(seconds, 60)
        ngettext("in %{count} min", "in %{count} min", minutes, count: minutes)

      seconds < 86_400 ->
        hours = div(seconds, 3600)
        ngettext("in %{count} hour", "in %{count} hours", hours, count: hours)

      seconds < 604_800 ->
        days = div(seconds, 86_400)
        ngettext("in %{count} day", "in %{count} days", days, count: days)

      seconds < 2_592_000 ->
        weeks = div(seconds, 604_800)
        ngettext("in %{count} week", "in %{count} weeks", weeks, count: weeks)

      true ->
        months = div(seconds, 2_592_000)
        ngettext("in %{count} month", "in %{count} months", months, count: months)
    end
  end
end





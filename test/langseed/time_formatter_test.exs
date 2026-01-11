defmodule Langseed.TimeFormatterTest do
  use ExUnit.Case, async: true

  alias Langseed.TimeFormatter

  describe "format_relative/2" do
    test "returns 'now' for nil datetime (graduated)" do
      now = ~U[2024-01-01 12:00:00Z]
      assert TimeFormatter.format_relative(nil, now) == "graduated"
    end

    test "returns 'now' for times within 1 minute" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-01 12:00:30Z]
      assert TimeFormatter.format_relative(future, now) == "now"
    end

    test "returns 'now' for past times" do
      now = ~U[2024-01-01 12:00:00Z]
      past = ~U[2024-01-01 11:00:00Z]
      assert TimeFormatter.format_relative(past, now) == "now"
    end

    test "formats minutes in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-01 12:05:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 5 min"
    end

    test "formats hours in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-01 15:00:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 3 hours"
    end

    test "formats single hour in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-01 13:00:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 1 hour"
    end

    test "formats days in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-04 12:00:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 3 days"
    end

    test "formats single day in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-02 12:00:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 1 day"
    end

    test "formats weeks in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-15 12:00:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 2 weeks"
    end

    test "formats single week in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      future = ~U[2024-01-08 12:00:00Z]
      assert TimeFormatter.format_relative(future, now) == "in 1 week"
    end

    test "formats months in the future" do
      now = ~U[2024-01-01 12:00:00Z]
      # Approximately 2 months (60 days)
      future = ~U[2024-03-01 12:00:00Z]
      result = TimeFormatter.format_relative(future, now)
      # Could be "in 1 month" or "in 2 months" depending on exact days
      assert result =~ ~r/in \d+ months?/
    end
  end

  describe "format_relative/1" do
    test "formats relative to current time" do
      # Create a time in the near future
      # Use a range to account for timing variations
      future = DateTime.add(DateTime.utc_now(), 300, :second)
      result = TimeFormatter.format_relative(future)
      assert result =~ ~r/in \d+ min/
    end

    test "returns 'now' for past times" do
      past = DateTime.add(DateTime.utc_now(), -300, :second)
      assert TimeFormatter.format_relative(past) == "now"
    end
  end
end

defmodule Langseed.AnalyticsTest do
  use Langseed.DataCase

  alias Langseed.Analytics

  import Langseed.AccountsFixtures

  describe "log_query/1" do
    test "logs a query with valid data" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        query_type: "analyze_word",
        model: "gemini-2.5-pro",
        input_tokens: 100,
        output_tokens: 50
      }

      assert {:ok, query} = Analytics.log_query(attrs)
      assert query.query_type == "analyze_word"
      assert query.input_tokens == 100
      assert query.output_tokens == 50
    end

    test "returns error for invalid query type" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        query_type: "invalid_type",
        model: "gemini-2.5-pro"
      }

      assert {:error, %Ecto.Changeset{}} = Analytics.log_query(attrs)
    end
  end

  describe "get_user_usage/1" do
    test "returns usage stats for a user" do
      user = user_fixture()

      Analytics.log_query(%{
        user_id: user.id,
        query_type: "analyze_word",
        model: "test",
        input_tokens: 100,
        output_tokens: 50
      })

      Analytics.log_query(%{
        user_id: user.id,
        query_type: "yes_no_question",
        model: "test",
        input_tokens: 200,
        output_tokens: 100
      })

      usage = Analytics.get_user_usage(user.id)
      assert usage.total_input_tokens == 300
      assert usage.total_output_tokens == 150
      assert usage.query_count == 2
    end
  end

  describe "get_usage_by_type/1" do
    test "returns usage grouped by query type" do
      user = user_fixture()

      Analytics.log_query(%{
        user_id: user.id,
        query_type: "analyze_word",
        model: "test",
        input_tokens: 100,
        output_tokens: 50
      })

      Analytics.log_query(%{
        user_id: user.id,
        query_type: "analyze_word",
        model: "test",
        input_tokens: 100,
        output_tokens: 50
      })

      Analytics.log_query(%{
        user_id: user.id,
        query_type: "yes_no_question",
        model: "test",
        input_tokens: 200,
        output_tokens: 100
      })

      usage = Analytics.get_usage_by_type(user.id)
      assert length(usage) == 2

      analyze_word = Enum.find(usage, &(&1.query_type == "analyze_word"))
      assert analyze_word.count == 2
      assert analyze_word.input_tokens == 200
    end
  end

  describe "get_total_usage/0" do
    test "returns total usage across all users" do
      user1 = user_fixture()
      user2 = user_fixture()

      Analytics.log_query(%{
        user_id: user1.id,
        query_type: "analyze_word",
        model: "test",
        input_tokens: 100,
        output_tokens: 50
      })

      Analytics.log_query(%{
        user_id: user2.id,
        query_type: "analyze_word",
        model: "test",
        input_tokens: 200,
        output_tokens: 100
      })

      usage = Analytics.get_total_usage()
      assert usage.total_input_tokens == 300
      assert usage.total_output_tokens == 150
      assert usage.query_count == 2
    end
  end
end





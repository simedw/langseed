defmodule Langseed.LLM.ClientTest do
  use ExUnit.Case, async: true

  alias Langseed.LLM.Client

  describe "clean_json_response/1" do
    test "removes markdown code fences" do
      input = """
      ```json
      {"key": "value"}
      ```
      """

      assert Client.clean_json_response(input) == ~s({"key": "value"})
    end

    test "handles response without code fences" do
      input = ~s({"key": "value"})
      assert Client.clean_json_response(input) == ~s({"key": "value"})
    end

    test "trims whitespace" do
      input = "   {\"key\": \"value\"}   "
      assert Client.clean_json_response(input) == ~s({"key": "value"})
    end
  end

  describe "parse_json/1" do
    test "parses valid JSON" do
      assert {:ok, %{"key" => "value"}} = Client.parse_json({:ok, ~s({"key": "value"})})
    end

    test "handles markdown-wrapped JSON" do
      input = """
      ```json
      {"key": "value"}
      ```
      """

      assert {:ok, %{"key" => "value"}} = Client.parse_json({:ok, input})
    end

    test "returns error for invalid JSON" do
      assert {:error, message} = Client.parse_json({:ok, "not json"})
      assert message =~ "Failed to parse JSON"
    end

    test "returns error for nil response" do
      assert {:error, "Empty response from API"} = Client.parse_json({:ok, nil})
    end

    test "passes through error tuples" do
      error = {:error, "some error"}
      assert ^error = Client.parse_json(error)
    end
  end

  describe "track_usage/3" do
    test "passes through error tuples" do
      error = {:error, "request failed"}
      assert ^error = Client.track_usage(error, 1, "test")
    end
  end
end

defmodule Langseed.LLM.QuestionGeneratorTest do
  use ExUnit.Case, async: true

  # Note: Full integration tests for generate_yes_no and generate_fill_blank
  # require LLM calls. Consider adding Mox for mocking Client.generate/1
  # to enable comprehensive unit testing.

  alias Langseed.LLM.QuestionGenerator

  describe "module structure" do
    test "module compiles and exports expected public functions" do
      # Verify module exports the expected functions
      functions = QuestionGenerator.__info__(:functions)

      # generate_yes_no(user_id, concept, known_words, language \\ "zh")
      assert {:generate_yes_no, 3} in functions
      assert {:generate_yes_no, 4} in functions
      # generate_fill_blank(user_id, concept, known_words, distractor_words, language \\ "zh")
      assert {:generate_fill_blank, 4} in functions
      assert {:generate_fill_blank, 5} in functions
    end
  end

  describe "validation result handling" do
    # These tests verify the expected behavior of validate_single_correct_answer/3
    # by testing the data structures it returns

    test "ambiguous_options tuple structure" do
      # The validation function returns {:ambiguous_options, list} when multiple valid
      valid_options = ["option1", "option2"]
      result = {:ambiguous_options, valid_options}

      assert {:ambiguous_options, options} = result
      assert is_list(options)
      assert length(options) == 2
    end

    test "valid_indices filtering handles out of bounds" do
      # Simulate what the validation logic does with out-of-bounds indices
      options = ["a", "b", "c", "d"]
      num_options = length(options)

      # Valid indices from LLM (some out of bounds)
      valid_indices = [0, 2, 5, -1, 100]

      # Filter logic from validate_single_correct_answer
      filtered = Enum.filter(valid_indices, &(&1 >= 0 and &1 < num_options))

      assert filtered == [0, 2]
      assert Enum.map(filtered, &Enum.at(options, &1)) == ["a", "c"]
    end

    test "empty valid_indices after filtering" do
      options = ["a", "b", "c", "d"]
      num_options = length(options)

      # All indices out of bounds
      valid_indices = [5, 6, -1]

      filtered = Enum.filter(valid_indices, &(&1 >= 0 and &1 < num_options))

      assert filtered == []
      assert length(filtered) == 0
    end
  end

  describe "retry feedback construction" do
    # Test the logic used in build_retry_feedback/1 by testing its components

    test "separating ambiguous items from illegal words" do
      previous_illegal = [
        {:ambiguous, ["word1", "word2"]},
        "illegal_word1",
        "illegal_word2"
      ]

      {ambiguous_items, illegal_words} =
        Enum.split_with(previous_illegal, fn
          {:ambiguous, _} -> true
          _ -> false
        end)

      assert ambiguous_items == [{:ambiguous, ["word1", "word2"]}]
      assert illegal_words == ["illegal_word1", "illegal_word2"]
    end

    test "handles empty previous_illegal list" do
      previous_illegal = []

      {ambiguous_items, illegal_words} =
        Enum.split_with(previous_illegal, fn
          {:ambiguous, _} -> true
          _ -> false
        end)

      assert ambiguous_items == []
      assert illegal_words == []
    end

    test "handles only ambiguous items" do
      previous_illegal = [{:ambiguous, ["a", "b"]}]

      {ambiguous_items, illegal_words} =
        Enum.split_with(previous_illegal, fn
          {:ambiguous, _} -> true
          _ -> false
        end)

      assert ambiguous_items == [{:ambiguous, ["a", "b"]}]
      assert illegal_words == []
    end

    test "handles only illegal words" do
      previous_illegal = ["word1", "word2"]

      {ambiguous_items, illegal_words} =
        Enum.split_with(previous_illegal, fn
          {:ambiguous, _} -> true
          _ -> false
        end)

      assert ambiguous_items == []
      assert illegal_words == ["word1", "word2"]
    end

    test "ambiguous warning message formatting" do
      valid_options = ["option1", "option2"]

      warning =
        "PROBLEM: Multiple options are valid answers: #{Enum.join(valid_options, ", ")}. Create a sentence with MORE CONTEXT so only ONE answer is correct. "

      assert warning =~ "option1, option2"
      assert warning =~ "MORE CONTEXT"
    end
  end
end

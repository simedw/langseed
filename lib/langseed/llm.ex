defmodule Langseed.LLM do
  @moduledoc """
  LLM integration for Chinese word analysis using Gemini.
  """

  @max_retries 3

  @doc """
  Analyzes a Chinese word within its context sentence to extract
  pinyin, meaning, part of speech, and a self-referential explanation.

  The explanation will only use characters from the known_words set + emojis.

  Returns {:ok, %{pinyin: ..., meaning: ..., part_of_speech: ..., explanation: ...}} or {:error, reason}
  """
  def analyze_word(word, context_sentence \\ nil, known_words \\ MapSet.new()) do
    known_chars = extract_known_chars(known_words)

    analyze_with_retry(word, context_sentence, known_chars, @max_retries, [])
  end

  defp analyze_with_retry(_word, _context, _known_chars, 0, illegal_chars) do
    {:error,
     "Failed after #{@max_retries} retries. Could not avoid characters: #{Enum.join(illegal_chars, ", ")}"}
  end

  defp analyze_with_retry(word, context_sentence, known_chars, retries_left, previous_illegal) do
    prompt = build_prompt(word, context_sentence, known_chars, previous_illegal)

    case call_gemini(prompt) do
      {:ok, response} ->
        case parse_response(response) do
          {:ok, analysis} ->
            # Filter explanations individually - keep valid ones
            {valid_explanations, all_illegal} =
              analysis.explanations
              |> Enum.reduce({[], []}, fn explanation, {valid, illegal_acc} ->
                illegal = find_illegal_chars(explanation, known_chars)

                if Enum.empty?(illegal) do
                  {[explanation | valid], illegal_acc}
                else
                  {valid, illegal_acc ++ illegal}
                end
              end)

            valid_explanations = Enum.reverse(valid_explanations)
            all_illegal = Enum.uniq(all_illegal)

            cond do
              # All explanations are valid
              length(valid_explanations) == length(analysis.explanations) ->
                {:ok, analysis}

              # Some valid explanations - accept them
              length(valid_explanations) > 0 ->
                {:ok, %{analysis | explanations: valid_explanations}}

              # No valid explanations but retries left - try again
              retries_left > 0 ->
                analyze_with_retry(
                  word,
                  context_sentence,
                  known_chars,
                  retries_left - 1,
                  all_illegal
                )

              # No valid explanations and no retries - fail
              true ->
                {:error,
                 "Failed after #{@max_retries} retries. Could not avoid characters: #{Enum.join(all_illegal, ", ")}"}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_known_chars(known_words) do
    known_words
    |> MapSet.to_list()
    |> Enum.flat_map(&String.graphemes/1)
    |> Enum.filter(&chinese_char?/1)
    |> MapSet.new()
  end

  defp chinese_char?(char) do
    # Check if character is a CJK unified ideograph
    case String.to_charlist(char) do
      [codepoint] when codepoint >= 0x4E00 and codepoint <= 0x9FFF -> true
      [codepoint] when codepoint >= 0x3400 and codepoint <= 0x4DBF -> true
      _ -> false
    end
  end

  defp ensure_valid_utf8(nil), do: nil

  defp ensure_valid_utf8(str) when is_binary(str) do
    if String.valid?(str) do
      str
    else
      # Extract only valid UTF-8 portions, dropping invalid bytes
      case :unicode.characters_to_binary(str, :utf8, :utf8) do
        {:error, valid, _} -> valid
        {:incomplete, valid, _} -> valid
        binary when is_binary(binary) -> binary
      end
    end
  end

  defp find_illegal_chars(text, known_chars) do
    # Find unknown Chinese characters
    illegal_chinese =
      text
      |> String.graphemes()
      |> Enum.filter(&chinese_char?/1)
      |> Enum.reject(&MapSet.member?(known_chars, &1))
      |> Enum.uniq()

    # Find English letters (cheating!)
    has_english = Regex.match?(~r/[a-zA-Z]/, text)

    if has_english do
      # Return a marker that English was used
      illegal_chinese ++ ["[英文]"]
    else
      illegal_chinese
    end
  end

  defp build_prompt(word, context_sentence, known_chars, previous_illegal) do
    # Ensure strings are valid UTF-8 before building prompt
    safe_word = ensure_valid_utf8(word)
    safe_sentence = ensure_valid_utf8(context_sentence)

    context_part =
      if safe_sentence && safe_sentence != "" do
        "The word appears in this sentence: \"#{safe_sentence}\"\n"
      else
        ""
      end

    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")

    retry_feedback =
      if Enum.empty?(previous_illegal) do
        ""
      else
        has_english_error = "[英文]" in previous_illegal
        illegal_chars = Enum.reject(previous_illegal, &(&1 == "[英文]"))

        english_warning =
          if has_english_error do
            "You used ENGLISH letters which is FORBIDDEN. "
          else
            ""
          end

        char_warning =
          if Enum.empty?(illegal_chars) do
            ""
          else
            "You used these FORBIDDEN characters: #{Enum.join(illegal_chars, " ")}. "
          end

        """

        ⚠️ RETRY: #{english_warning}#{char_warning}Use ONLY allowed Chinese characters or emojis. NO ENGLISH AT ALL.
        """
      end

    """
    Analyze this Chinese word: "#{safe_word}"
    #{context_part}
    Respond ONLY with a JSON object in this exact format (no markdown, no code blocks):
    {
      "pinyin": "pinyin with tone marks",
      "meaning": "English meaning",
      "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, particle, numeral, measure_word, interjection, other",
      "explanations": ["explanation1", "explanation2", "explanation3"],
      "explanation_quality": 1-5,
      "desired_words": ["word1", "word2"]
    }

    CRITICAL RULES for the explanations field:
    - Provide 2-3 DIFFERENT explanations using different approaches:
      1. A short example sentence showing usage (use ____ for the word's position)
      2. An emoji-based visual hint
      3. A simple contextual phrase if possible
    - Each explanation should help understand the word from a DIFFERENT angle
    - ABSOLUTELY NO ENGLISH - not even single letters or quoted words
    - DO NOT break down the word into its component characters
    - The explanations MUST use ONLY these Chinese characters: #{known_chars_list}
    - You can use emojis freely
    - You can use numbers, punctuation, and spaces
    - Use ____ to show where the word fits in example sentences
    - Keep each explanation SHORT

    GOOD examples for 所以 (therefore): ["我 很 累，____ 我 要 休息", "1️⃣ ➡️ 2️⃣", "A，____ B"]
    GOOD examples for 好: ["👍😊", "很 ____！", "我 ____ 吃"]
    BAD examples: "你 是 you", "'hello'", "A is B"

    EXPLANATION_QUALITY (1-5):
    - 5: Perfect explanations using available characters
    - 4: Good, captures the meaning well
    - 3: Adequate, could be clearer
    - 2: Limited, mostly emojis
    - 1: Very poor

    DESIRED_WORDS: List 0-5 Chinese words that would help write better explanations.
    #{retry_feedback}
    """
  end

  defp call_gemini(prompt) do
    case ReqLLM.generate_text("google:gemini-2.5-pro", prompt) do
      {:ok, response} ->
        text = ReqLLM.Response.text(response)
        {:ok, text}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp parse_response(nil), do: {:error, "Empty response from API"}

  defp parse_response(response) do
    # Clean up the response - remove potential markdown code blocks
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, %{"pinyin" => pinyin, "meaning" => meaning, "part_of_speech" => pos} = data} ->
        # Handle both old "explanation" (string) and new "explanations" (array) format
        explanations =
          case {Map.get(data, "explanations"), Map.get(data, "explanation")} do
            {list, _} when is_list(list) -> list |> Enum.filter(&is_binary/1) |> Enum.take(5)
            {_, str} when is_binary(str) and str != "" -> [str]
            _ -> []
          end

        explanation_quality = Map.get(data, "explanation_quality") |> normalize_quality()
        desired_words = Map.get(data, "desired_words", []) |> normalize_desired_words()

        {:ok,
         %{
           pinyin: pinyin,
           meaning: meaning,
           part_of_speech: normalize_part_of_speech(pos),
           explanations: explanations,
           explanation_quality: explanation_quality,
           desired_words: desired_words
         }}

      {:ok, _} ->
        {:error, "Invalid response format"}

      {:error, _} ->
        {:error, "Failed to parse JSON response: #{cleaned}"}
    end
  end

  defp normalize_quality(nil), do: nil
  defp normalize_quality(q) when is_integer(q) and q >= 1 and q <= 5, do: q
  defp normalize_quality(q) when is_integer(q) and q < 1, do: 1
  defp normalize_quality(q) when is_integer(q) and q > 5, do: 5
  defp normalize_quality(_), do: nil

  defp normalize_desired_words(nil), do: []

  defp normalize_desired_words(words) when is_list(words) do
    words
    |> Enum.filter(&is_binary/1)
    |> Enum.take(5)
  end

  defp normalize_desired_words(_), do: []

  defp normalize_part_of_speech(pos) do
    pos
    |> String.downcase()
    |> String.replace(" ", "_")
    |> case do
      p
      when p in ~w(noun verb adjective adverb pronoun preposition conjunction particle numeral measure_word interjection) ->
        p

      _ ->
        "other"
    end
  end

  # =============================================================================
  # Practice Question Generation
  # =============================================================================

  @doc """
  Generates a Yes/No question about the target word using only known vocabulary.
  Returns {:ok, %{question: ..., answer: true/false}} or {:error, reason}
  """
  def generate_yes_no_question(concept, known_words) do
    known_chars = extract_known_chars(known_words)
    # Add characters from the target word to allowed set
    target_chars = concept.word |> String.graphemes() |> MapSet.new()
    allowed_chars = MapSet.union(known_chars, target_chars)

    generate_yes_no_with_retry(concept, known_chars, allowed_chars, [], 3)
  end

  defp generate_yes_no_with_retry(_concept, _known_chars, _allowed_chars, _previous_illegal, 0) do
    {:error, "Failed to generate valid question after 3 attempts"}
  end

  defp generate_yes_no_with_retry(concept, known_chars, allowed_chars, previous_illegal, attempts) do
    prompt = build_yes_no_prompt(concept, known_chars, previous_illegal)

    case call_gemini(prompt) do
      {:ok, response} ->
        case parse_yes_no_response(response) do
          {:ok, result} ->
            # Validate that question only uses allowed characters
            illegal = find_illegal_chars(result.question, allowed_chars)

            if Enum.empty?(illegal) do
              {:ok, result}
            else
              generate_yes_no_with_retry(
                concept,
                known_chars,
                allowed_chars,
                illegal,
                attempts - 1
              )
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_yes_no_prompt(concept, known_chars, previous_illegal) do
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")

    retry_feedback = build_retry_feedback(previous_illegal)

    """
    Generate a Yes/No question in Chinese to test understanding of the word "#{concept.word}" (#{concept.meaning}).
    #{retry_feedback}
    RULES:
    - The question must be answerable with YES (是/对) or NO (不是/不对)
    - Use ONLY these Chinese characters: #{known_chars_list}
    - You can also use: #{concept.word}
    - Use emojis if helpful
    - The question should test if the learner understands the MEANING of the word
    - Make the question clear and unambiguous
    - DO NOT use any Chinese character not in the allowed list above!

    Respond ONLY with JSON (no markdown):
    {"question": "Chinese question here", "answer": true or false, "explanation": "brief Chinese explanation of why"}

    Example for 晚上 (night):
    {"question": "太阳 在 晚上 出来 吗？", "answer": false, "explanation": "太阳 在 白天 出来，不是 晚上"}
    """
  end

  defp parse_yes_no_response(response) do
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, %{"question" => question, "answer" => answer} = data} ->
        {:ok,
         %{
           question: question,
           answer: answer == true,
           explanation: Map.get(data, "explanation", "")
         }}

      {:ok, _} ->
        {:error, "Invalid yes/no question format"}

      {:error, _} ->
        {:error, "Failed to parse yes/no question: #{cleaned}"}
    end
  end

  @doc """
  Generates a fill-in-the-blank question with multiple choice options.
  Returns {:ok, %{sentence: ..., options: [...], correct_index: 0-3}} or {:error, reason}
  """
  def generate_fill_blank_question(concept, known_words, distractor_words) do
    known_chars = extract_known_chars(known_words)
    # Add characters from the target word and distractors to allowed set
    target_chars = concept.word |> String.graphemes() |> MapSet.new()

    distractor_chars =
      distractor_words
      |> Enum.flat_map(&String.graphemes(&1.word))
      |> MapSet.new()

    allowed_chars =
      known_chars
      |> MapSet.union(target_chars)
      |> MapSet.union(distractor_chars)

    generate_fill_blank_with_retry(concept, known_chars, allowed_chars, distractor_words, [], 3)
  end

  defp generate_fill_blank_with_retry(
         _concept,
         _known_chars,
         _allowed_chars,
         _distractors,
         _previous_illegal,
         0
       ) do
    {:error, "Failed to generate valid fill-blank question after 3 attempts"}
  end

  defp generate_fill_blank_with_retry(
         concept,
         known_chars,
         allowed_chars,
         distractor_words,
         previous_illegal,
         attempts
       ) do
    prompt = build_fill_blank_prompt(concept, known_chars, distractor_words, previous_illegal)

    case call_gemini(prompt) do
      {:ok, response} ->
        case parse_fill_blank_response(response) do
          {:ok, result} ->
            # Validate that sentence only uses allowed characters (excluding the blank marker)
            sentence_without_blank = String.replace(result.sentence, "____", "")
            illegal = find_illegal_chars(sentence_without_blank, allowed_chars)

            if Enum.empty?(illegal) do
              {:ok, result}
            else
              generate_fill_blank_with_retry(
                concept,
                known_chars,
                allowed_chars,
                distractor_words,
                illegal,
                attempts - 1
              )
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_fill_blank_prompt(concept, known_chars, distractor_words, previous_illegal) do
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")
    distractors = distractor_words |> Enum.take(3) |> Enum.map(& &1.word) |> Enum.join(", ")

    retry_feedback = build_retry_feedback(previous_illegal)

    """
    Generate a fill-in-the-blank sentence in Chinese to test the word "#{concept.word}" (#{concept.meaning}).
    #{retry_feedback}
    RULES:
    - Create a sentence where "#{concept.word}" fits naturally in the blank
    - Use ONLY these Chinese characters (plus the blank): #{known_chars_list}
    - Mark the blank with ____
    - The context should make the correct answer clear
    - DO NOT use any Chinese character not in the allowed list above!

    The correct answer is: #{concept.word}
    Distractor options (wrong answers): #{distractors}

    Respond ONLY with JSON (no markdown):
    {"sentence": "我 喜欢 ____ 书", "options": ["#{concept.word}", "option2", "option3", "option4"], "correct_index": 0}

    IMPORTANT: Shuffle the options randomly, correct_index should match where #{concept.word} ends up (0-3).
    """
  end

  defp build_retry_feedback([]), do: ""

  defp build_retry_feedback(previous_illegal) do
    has_english_error = "[英文]" in previous_illegal
    illegal_chars = Enum.reject(previous_illegal, &(&1 == "[英文]"))

    english_warning =
      if has_english_error do
        "You used ENGLISH letters which is FORBIDDEN. "
      else
        ""
      end

    char_warning =
      if Enum.empty?(illegal_chars) do
        ""
      else
        "You used these FORBIDDEN characters: #{Enum.join(illegal_chars, " ")}. "
      end

    """

    ⚠️ RETRY: #{english_warning}#{char_warning}Use ONLY allowed Chinese characters. NO unknown characters!
    """
  end

  defp parse_fill_blank_response(response) do
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, %{"sentence" => sentence, "options" => options, "correct_index" => idx}}
      when is_list(options) and is_integer(idx) ->
        {:ok,
         %{
           sentence: sentence,
           options: options,
           correct_index: idx
         }}

      {:ok, _} ->
        {:error, "Invalid fill-blank question format"}

      {:error, _} ->
        {:error, "Failed to parse fill-blank question: #{cleaned}"}
    end
  end

  @doc """
  Evaluates a sentence written by the user using the target word.
  Returns {:ok, %{correct: true/false, feedback: "..."}} or {:error, reason}
  """
  def evaluate_sentence(concept, user_sentence, known_words) do
    known_chars = extract_known_chars(known_words)
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")

    prompt = """
    Evaluate this Chinese sentence written by a learner.

    Target word they should use: "#{concept.word}" (#{concept.meaning})
    Learner's sentence: "#{user_sentence}"
    Words the learner knows (characters): #{known_chars_list}

    Check if:
    1. The sentence uses "#{concept.word}" correctly
    2. The sentence is grammatically reasonable
    3. The sentence makes sense

    Respond ONLY with JSON (no markdown):
    {"correct": true/false, "feedback": "Chinese feedback for the learner", "improved": "optional improved version if incorrect"}

    Be encouraging! If mostly correct with small errors, still mark as correct but give tips.
    Use ONLY known characters in your feedback, or use emojis.
    """

    case call_gemini(prompt) do
      {:ok, response} -> parse_evaluation_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_evaluation_response(response) do
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, %{"correct" => correct, "feedback" => feedback} = data} ->
        {:ok,
         %{
           correct: correct == true,
           feedback: feedback,
           improved: Map.get(data, "improved")
         }}

      {:ok, _} ->
        {:error, "Invalid evaluation format"}

      {:error, _} ->
        {:error, "Failed to parse evaluation: #{cleaned}"}
    end
  end

  @doc """
  Regenerates explanations for a word using only known vocabulary.
  Returns {:ok, [explanations]} or {:error, reason}
  """
  def regenerate_explanation(concept, known_words) do
    known_chars = extract_known_chars(known_words)
    known_chars_list = known_chars |> MapSet.to_list() |> Enum.join("")
    previous = Enum.join(concept.explanations || [], ", ")

    prompt = """
    Create NEW, DIFFERENT explanations for the Chinese word "#{concept.word}" (#{concept.meaning}).

    Previous explanations were: "#{previous}"
    Please create DIFFERENT explanations using different approaches.

    RULES:
    - Provide 2-3 DIFFERENT explanations:
      1. A short example sentence (use ____ for where the word goes)
      2. An emoji-based visual hint
      3. A contextual phrase if possible
    - Use ONLY these Chinese characters: #{known_chars_list}
    - You can use emojis freely
    - NO ENGLISH at all
    - Keep each short and visual
    - Try different angles than the previous explanations

    Respond ONLY with JSON (no markdown):
    {"explanations": ["explanation1", "explanation2", "explanation3"]}
    """

    case call_gemini(prompt) do
      {:ok, response} ->
        cleaned =
          response
          |> String.trim()
          |> String.replace(~r/^```json\n?/, "")
          |> String.replace(~r/\n?```$/, "")
          |> String.trim()

        case Jason.decode(cleaned) do
          {:ok, %{"explanations" => explanations}} when is_list(explanations) ->
            valid_explanations =
              explanations
              |> Enum.filter(&is_binary/1)
              |> Enum.filter(fn exp ->
                illegal = find_illegal_chars(exp, known_chars)
                Enum.empty?(illegal)
              end)
              |> Enum.take(3)

            if Enum.empty?(valid_explanations) do
              {:ok, ["🤔💭 #{concept.word}"]}
            else
              {:ok, valid_explanations}
            end

          _ ->
            {:ok, ["🤔💭 #{concept.word}"]}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

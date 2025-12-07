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
            # Validate the explanation only contains known characters
            illegal = find_illegal_chars(analysis.explanation, known_chars)

            if Enum.empty?(illegal) do
              {:ok, analysis}
            else
              # Retry with feedback about illegal characters
              analyze_with_retry(word, context_sentence, known_chars, retries_left - 1, illegal)
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
    context_part =
      if context_sentence do
        "The word appears in this sentence: \"#{context_sentence}\"\n"
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
    Analyze this Chinese word: "#{word}"
    #{context_part}
    Respond ONLY with a JSON object in this exact format (no markdown, no code blocks):
    {
      "pinyin": "pinyin with tone marks",
      "meaning": "English meaning",
      "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, particle, numeral, measure_word, interjection, other",
      "explanation": "explanation using ONLY allowed Chinese characters and emojis",
      "explanation_quality": 1-5,
      "desired_words": ["word1", "word2"]
    }

    CRITICAL RULES for the explanation field:
    - ABSOLUTELY NO ENGLISH - not even single letters or quoted words
    - DO NOT break down the word into its component characters
    - DO NOT explain what each character means separately
    - Explain the WHOLE WORD's meaning using context, examples, or emojis
    - The explanation MUST use ONLY these Chinese characters: #{known_chars_list}
    - You can use emojis freely (👍🔥💧🚶👀🎬📺 etc.)
    - You can use numbers, punctuation (。，！？), and spaces
    - DO NOT use any Chinese character that is not in the allowed list
    - If you cannot explain with allowed characters, use ONLY emojis
    - Keep it SHORT - a simple phrase or emojis, not a definition

    GOOD examples: "👋😊", "我 喜欢 看 🎬", "很 好 吃 🍜"
    BAD examples: "你 是 you", "'hello'", "A is B"

    EXPLANATION_QUALITY (1-5):
    - 5: Perfect explanation using available characters
    - 4: Good explanation, captures the meaning well
    - 3: Adequate, but could be clearer with more words
    - 2: Limited, mostly emojis due to lack of vocabulary
    - 1: Very poor, couldn't really explain it

    DESIRED_WORDS: List 0-5 Chinese words that would help you write a better explanation.
    These should be common, useful words that would be good for the learner to learn next.
    Leave empty [] if the explanation is already perfect.
    #{retry_feedback}
    """
  end

  defp call_gemini(prompt) do
    case ReqLLM.generate_text("google:gemini-2.5-flash", prompt) do
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
        explanation = Map.get(data, "explanation", "")
        explanation_quality = Map.get(data, "explanation_quality") |> normalize_quality()
        desired_words = Map.get(data, "desired_words", []) |> normalize_desired_words()

        {:ok,
         %{
           pinyin: pinyin,
           meaning: meaning,
           part_of_speech: normalize_part_of_speech(pos),
           explanation: explanation,
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
end

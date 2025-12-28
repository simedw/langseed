defmodule Langseed.Services.WordImporter do
  @moduledoc """
  Service for importing words into a user's vocabulary using LLM analysis.
  """

  alias Langseed.Accounts.Scope
  alias Langseed.LLM
  alias Langseed.Utils.StringUtils
  alias Langseed.Vocabulary
  alias Langseed.Workers.QuestionGenerator

  @doc """
  Imports a list of words into the scope's vocabulary.

  Uses LLM to analyze each word and extract pinyin, meaning, and explanations.
  Falls back to placeholder values if LLM analysis fails.

  Returns `{added, failed}` where each is a list of word strings.
  """
  @spec import_words(Scope.t() | nil, [String.t()], String.t()) ::
          {added :: [String.t()], failed :: [String.t()]}
  def import_words(scope, words, context) do
    # Get current known words to pass to LLM for explanation generation
    known_words = Vocabulary.known_words(scope)
    # Capture user_id and language for use in async tasks
    user_id = if scope, do: scope.user.id, else: nil
    language = if scope, do: scope.language, else: "zh"
    # Sanitize context once
    safe_context = StringUtils.ensure_valid_utf8(context)

    # Process words in parallel for faster LLM calls
    results =
      words
      |> Task.async_stream(
        fn word ->
          import_single_word(scope, user_id, language, word, safe_context, known_words)
        end,
        max_concurrency: 5,
        timeout: 60_000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, _reason} -> {:error, "timeout"}
      end)

    added = results |> Enum.filter(&match?({:ok, _}, &1)) |> Enum.map(&elem(&1, 1))
    failed = results |> Enum.filter(&match?({:error, _}, &1)) |> Enum.map(&elem(&1, 1))

    # Trigger question generation for the user if any words were added
    if not Enum.empty?(added) && scope do
      QuestionGenerator.enqueue(scope.user)
    end

    {added, failed}
  end

  defp import_single_word(scope, user_id, language, word, context, known_words) do
    # Extract just the sentence containing the word
    sentence = extract_sentence(context, word, language)
    # Extra safety: ensure sentence is valid UTF-8 before DB insert
    safe_sentence = StringUtils.ensure_valid_utf8(sentence)

    case LLM.analyze_word(user_id, word, safe_sentence, known_words, language) do
      {:ok, analysis} ->
        create_concept_from_analysis(scope, word, safe_sentence, analysis)

      {:error, _reason} ->
        create_fallback_concept(scope, word, safe_sentence)
    end
  end

  defp create_concept_from_analysis(scope, word, sentence, analysis) do
    attrs = %{
      word: StringUtils.ensure_valid_utf8(word),
      pinyin: StringUtils.ensure_valid_utf8(analysis.pinyin),
      meaning: StringUtils.ensure_valid_utf8(analysis.meaning),
      part_of_speech: analysis.part_of_speech,
      explanations: Enum.map(analysis.explanations, &StringUtils.ensure_valid_utf8/1),
      explanation_quality: analysis.explanation_quality,
      desired_words: Enum.map(analysis.desired_words, &StringUtils.ensure_valid_utf8/1),
      example_sentence: sentence,
      understanding: 0
    }

    case Vocabulary.create_concept(scope, attrs) do
      {:ok, concept} ->
        # Generate audio synchronously so it's ready for the modal
        generate_and_store_audio(concept)
        {:ok, word}

      {:error, _} ->
        {:error, word}
    end
  end

  defp create_fallback_concept(scope, word, sentence) do
    attrs = %{
      word: StringUtils.ensure_valid_utf8(word),
      pinyin: "?",
      meaning: "?",
      part_of_speech: "other",
      explanations: ["❓"],
      explanation_quality: 1,
      desired_words: [],
      example_sentence: sentence,
      understanding: 0
    }

    case Vocabulary.create_concept(scope, attrs) do
      {:ok, concept} ->
        # Generate audio synchronously so it's ready for the modal
        generate_and_store_audio(concept)
        {:ok, word}

      {:error, _} ->
        {:error, word}
    end
  end

  # Generate audio for the word if TTS is available
  # Stores the stable R2 object path, NOT the signed URL (which expires)
  defp generate_and_store_audio(concept) do
    alias Langseed.Audio

    if Audio.available?() && concept.language == "zh" do
      case Audio.generate_word_audio(concept) do
        {:ok, _signed_url} ->
          # Persist the stable path (not the signed URL)
          path = Audio.audio_path_for(concept.word, concept.language)
          Audio.persist_audio_path(concept, path)

        _ ->
          # Fail silently - audio is optional
          :ok
      end
    end
  end

  defp extract_sentence(text, word, language) do
    # Split by sentence endings based on language
    sentence_pattern =
      case language do
        "zh" -> ~r/[。！？\n]+/
        _ -> ~r/[.!?\n]+/
      end

    sentences =
      text
      |> String.split(sentence_pattern, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Find the first sentence containing the word, fallback to first sentence
    case Enum.find(sentences, fn s -> String.contains?(s, word) end) do
      nil -> List.first(sentences) || word
      found -> found
    end
  end
end

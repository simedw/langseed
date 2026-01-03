defmodule Langseed.Language.Japanese do
  @moduledoc """
  Japanese language implementation using TinySegmenter for word segmentation.

  TinySegmenter is a compact, pure-Elixir Japanese tokenizer that uses
  machine learning-based segmentation with pre-trained models. It provides
  accurate word boundaries without requiring any external system dependencies.
  """

  @behaviour Langseed.Language

  @impl true
  @spec segment(String.t()) :: [Langseed.Language.segment()]
  def segment(text) do
    text
    |> String.split(~r/(\n)/, include_captures: true)
    |> Enum.flat_map(&segment_part/1)
  end

  defp segment_part("\n"), do: [{:newline, "\n"}]

  defp segment_part(part) do
    part
    |> TinySegmenter.tokenize()
    |> Enum.map(&token_to_segment/1)
  end

  defp token_to_segment(token) do
    cond do
      String.trim(token) == "" ->
        {:space, token}

      Regex.match?(~r/^[\p{P}\p{S}]+$/u, token) ->
        {:punct, token}

      true ->
        {:word, token}
    end
  end

  @impl true
  @spec word_char?(String.t()) :: boolean()
  def word_char?(grapheme) do
    case String.to_charlist(grapheme) do
      # Hiragana: U+3040–U+309F
      [codepoint] when codepoint >= 0x3040 and codepoint <= 0x309F -> true
      # Katakana: U+30A0–U+30FF
      [codepoint] when codepoint >= 0x30A0 and codepoint <= 0x30FF -> true
      # CJK Unified Ideographs (Kanji): U+4E00–U+9FFF
      [codepoint] when codepoint >= 0x4E00 and codepoint <= 0x9FFF -> true
      # CJK Extension A: U+3400–U+4DBF
      [codepoint] when codepoint >= 0x3400 and codepoint <= 0x4DBF -> true
      # Katakana Phonetic Extensions: U+31F0–U+31FF
      [codepoint] when codepoint >= 0x31F0 and codepoint <= 0x31FF -> true
      # Halfwidth Katakana: U+FF65–U+FF9F
      [codepoint] when codepoint >= 0xFF65 and codepoint <= 0xFF9F -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a kanji character.
  """
  def kanji_char?(grapheme) do
    case String.to_charlist(grapheme) do
      [codepoint] when codepoint >= 0x4E00 and codepoint <= 0x9FFF -> true
      [codepoint] when codepoint >= 0x3400 and codepoint <= 0x4DBF -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a hiragana character.
  """
  def hiragana_char?(grapheme) do
    case String.to_charlist(grapheme) do
      [codepoint] when codepoint >= 0x3040 and codepoint <= 0x309F -> true
      _ -> false
    end
  end

  @doc """
  Checks if a character is a katakana character.
  """
  def katakana_char?(grapheme) do
    case String.to_charlist(grapheme) do
      [codepoint] when codepoint >= 0x30A0 and codepoint <= 0x30FF -> true
      [codepoint] when codepoint >= 0x31F0 and codepoint <= 0x31FF -> true
      [codepoint] when codepoint >= 0xFF65 and codepoint <= 0xFF9F -> true
      _ -> false
    end
  end

  @impl true
  @spec extract_chars(MapSet.t()) :: MapSet.t()
  def extract_chars(words) do
    words
    |> MapSet.to_list()
    |> Enum.flat_map(&String.graphemes/1)
    |> Enum.filter(&word_char?/1)
    |> MapSet.new()
  end

  @impl true
  @spec find_unknown_chars(String.t(), MapSet.t()) :: [String.t()]
  def find_unknown_chars(text, known_chars) do
    # Find unknown Japanese characters (kanji primarily)
    unknown_chars =
      text
      |> String.graphemes()
      |> Enum.filter(&kanji_char?/1)
      |> Enum.reject(&MapSet.member?(known_chars, &1))
      |> Enum.uniq()

    # Check for non-Japanese text (English, etc.)
    has_foreign = Regex.match?(~r/[a-zA-Z]/, text)

    if has_foreign do
      unknown_chars ++ ["[外国語]"]
    else
      unknown_chars
    end
  end

  @impl true
  @spec find_unknown_words(String.t(), MapSet.t()) :: [String.t()]
  def find_unknown_words(text, known_words) do
    # Segment text into words
    segments = segment(text)

    # Find unknown words not in vocabulary
    unknown_words =
      segments
      |> Enum.filter(fn
        {:word, word} -> not MapSet.member?(known_words, word)
        _ -> false
      end)
      |> Enum.map(fn {:word, word} -> word end)
      |> Enum.uniq()

    # Check for non-Japanese text
    has_foreign = Regex.match?(~r/[a-zA-Z]/, text)

    if has_foreign do
      unknown_words ++ ["[外国語]"]
    else
      unknown_words
    end
  end
end

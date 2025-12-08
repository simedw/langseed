defmodule Langseed.Language.Chinese do
  @moduledoc """
  Chinese language implementation using Jieba for word segmentation.
  """

  @behaviour Langseed.Language

  @impl true
  @spec segment(String.t()) :: [Langseed.Language.segment()]
  def segment(text) do
    {:ok, jieba} = Jieba.new()

    text
    |> String.split(~r/(\n)/, include_captures: true)
    |> Enum.flat_map(&segment_part(&1, jieba))
  end

  defp segment_part("\n", _jieba), do: [{:newline, "\n"}]

  defp segment_part(part, jieba) do
    jieba
    |> Jieba.cut(part)
    |> Enum.map(&classify_token/1)
  end

  defp classify_token(word) do
    cond do
      String.trim(word) == "" -> {:space, word}
      Regex.match?(~r/^[\p{P}\p{S}]+$/u, word) -> {:punct, word}
      true -> {:word, word}
    end
  end

  @impl true
  @spec word_char?(String.t()) :: boolean()
  def word_char?(grapheme) do
    # Check if character is a CJK unified ideograph
    case String.to_charlist(grapheme) do
      [codepoint] when codepoint >= 0x4E00 and codepoint <= 0x9FFF -> true
      [codepoint] when codepoint >= 0x3400 and codepoint <= 0x4DBF -> true
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
    # Find unknown Chinese characters
    unknown_chinese =
      text
      |> String.graphemes()
      |> Enum.filter(&word_char?/1)
      |> Enum.reject(&MapSet.member?(known_chars, &1))
      |> Enum.uniq()

    # Find English letters (cheating!)
    has_english = Regex.match?(~r/[a-zA-Z]/, text)

    if has_english do
      # Return a marker that English was used
      unknown_chinese ++ ["[英文]"]
    else
      unknown_chinese
    end
  end

  @impl true
  @spec find_unknown_words(String.t(), MapSet.t()) :: [String.t()]
  def find_unknown_words(text, known_words) do
    # Segment text into words
    segments = segment(text)

    # Find unknown words (multi-character words not in vocabulary)
    unknown_words =
      segments
      |> Enum.filter(fn
        {:word, word} -> String.length(word) > 1 and not MapSet.member?(known_words, word)
        _ -> false
      end)
      |> Enum.map(fn {:word, word} -> word end)
      |> Enum.uniq()

    # Find English letters (cheating!)
    has_english = Regex.match?(~r/[a-zA-Z]/, text)

    if has_english do
      unknown_words ++ ["[英文]"]
    else
      unknown_words
    end
  end
end

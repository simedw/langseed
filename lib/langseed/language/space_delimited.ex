defmodule Langseed.Language.SpaceDelimited do
  @moduledoc """
  Generic language implementation for space-delimited languages like English and Swedish.
  Words are separated by whitespace and punctuation.
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
    # Split on word boundaries, preserving punctuation and spaces
    part
    |> String.split(~r/([\s]+|[^\w\s]+)/u, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&classify_token/1)
  end

  defp classify_token(token) do
    cond do
      String.match?(token, ~r/^\s+$/) -> {:space, token}
      String.match?(token, ~r/^[\p{P}\p{S}]+$/u) -> {:punct, token}
      true -> {:word, String.downcase(token)}
    end
  end

  @impl true
  @spec word_char?(String.t()) :: boolean()
  def word_char?(grapheme) do
    # Letters and numbers are word characters
    String.match?(grapheme, ~r/^[\p{L}\p{N}]$/u)
  end

  @impl true
  @spec extract_chars(MapSet.t()) :: MapSet.t()
  def extract_chars(words) do
    # For space-delimited languages, characters are less meaningful
    # but we still extract them for consistency
    words
    |> MapSet.to_list()
    |> Enum.flat_map(&String.graphemes/1)
    |> Enum.filter(&word_char?/1)
    |> MapSet.new()
  end

  @impl true
  @spec find_unknown_chars(String.t(), MapSet.t()) :: [String.t()]
  def find_unknown_chars(text, known_chars) do
    text
    |> String.graphemes()
    |> Enum.filter(&word_char?/1)
    |> Enum.reject(&MapSet.member?(known_chars, &1))
    |> Enum.uniq()
  end

  @impl true
  @spec find_unknown_words(String.t(), MapSet.t()) :: [String.t()]
  def find_unknown_words(text, known_words) do
    # Normalize known_words to lowercase for comparison
    known_words_lower = MapSet.new(known_words, &String.downcase/1)

    segments = segment(text)

    segments
    |> Enum.filter(fn
      {:word, word} -> not MapSet.member?(known_words_lower, String.downcase(word))
      _ -> false
    end)
    |> Enum.map(fn {:word, word} -> word end)
    |> Enum.uniq()
  end
end


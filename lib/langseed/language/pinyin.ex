defmodule Langseed.Language.Pinyin do
  @moduledoc """
  Utilities for working with Chinese pinyin.

  Handles conversion between tone-marked pinyin (e.g., "nǐ hǎo") and
  numbered pinyin (e.g., "ni3 hao3").

  Built on top of the hanyutils library for reliable syllable parsing.
  """

  @doc """
  Converts tone-marked pinyin to numbered pinyin format.

  ## Examples

      iex> Langseed.Language.Pinyin.to_numbered("nǐ hǎo")
      "ni3 hao3"

      iex> Langseed.Language.Pinyin.to_numbered("tāo qì")
      "tao1 qi4"

      iex> Langseed.Language.Pinyin.to_numbered("ài")
      "ai4"

      iex> Langseed.Language.Pinyin.to_numbered("suǒ yǐ")
      "suo3 yi3"
  """
  @spec to_numbered(String.t()) :: String.t()
  def to_numbered(pinyin) when is_binary(pinyin) do
    # If already contains digits, it's already numbered - return as-is
    if String.match?(pinyin, ~r/[1-5]/) do
      pinyin
    else
      Hanyutils.number_pinyin(pinyin)
    end
  end

  def to_numbered(nil), do: nil

  @doc """
  Normalizes user input pinyin for comparison.

  - Converts to lowercase
  - Converts tone marks to numbers
  - Removes whitespace

  ## Examples

      iex> Langseed.Language.Pinyin.normalize("Ni3 Hao3")
      "ni3hao3"

      iex> Langseed.Language.Pinyin.normalize("nǚ")
      "nv3"
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(pinyin) when is_binary(pinyin) do
    pinyin
    |> String.downcase()
    |> to_numbered()
    |> String.replace(~r/\s+/, "")
    |> String.replace("ü", "v")
  end

  def normalize(nil), do: nil

  @doc """
  Checks if two pinyin strings match (after normalization).

  ## Examples

      iex> Langseed.Language.Pinyin.match?("ni3hao3", "nǐ hǎo")
      true

      iex> Langseed.Language.Pinyin.match?("ni3hao3", "ni3 hao3")
      true
  """
  @spec match?(String.t(), String.t()) :: boolean()
  def match?(input, expected) do
    normalize(input) == normalize(expected)
  end

  @doc """
  Parses pinyin text and returns a list of syllables with their detected tones.

  Returns a list of tuples where each tuple contains the syllable text and
  its tone number (1-4) or nil for neutral tone/no tone mark.

  Handles both spaced pinyin ("nǐ hǎo") and compound pinyin ("rúguǒ").

  ## Examples

      iex> Langseed.Language.Pinyin.syllables_with_tones("nǐ hǎo")
      [{"nǐ", 3}, {"hǎo", 3}]

      iex> Langseed.Language.Pinyin.syllables_with_tones("tāo qì")
      [{"tāo", 1}, {"qì", 4}]

      iex> Langseed.Language.Pinyin.syllables_with_tones("rúguǒ")
      [{"rú", 2}, {"guǒ", 3}]

      iex> Langseed.Language.Pinyin.syllables_with_tones("de")
      [{"de", nil}]
  """
  @spec syllables_with_tones(String.t()) :: [{String.t(), integer() | nil}]
  def syllables_with_tones(pinyin) when is_binary(pinyin) do
    pinyin
    |> String.replace("'", "")
    |> Pinyin.read!()
    |> Enum.filter(&is_struct(&1, Pinyin))
    |> Enum.map(fn syllable ->
      {Pinyin.marked(syllable), syllable.tone}
    end)
  end

  def syllables_with_tones(nil), do: []
end

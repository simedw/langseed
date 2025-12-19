defmodule Langseed.Language.Pinyin do
  @moduledoc """
  Utilities for working with Chinese pinyin.

  Handles conversion between tone-marked pinyin (e.g., "nǐ hǎo") and
  numbered pinyin (e.g., "ni3 hao3").
  """

  # Mapping of tone-marked vowels to their base vowel and tone number
  @tone_marks %{
    # First tone (flat)
    "ā" => {"a", "1"},
    "ē" => {"e", "1"},
    "ī" => {"i", "1"},
    "ō" => {"o", "1"},
    "ū" => {"u", "1"},
    "ǖ" => {"v", "1"},
    # Second tone (rising)
    "á" => {"a", "2"},
    "é" => {"e", "2"},
    "í" => {"i", "2"},
    "ó" => {"o", "2"},
    "ú" => {"u", "2"},
    "ǘ" => {"v", "2"},
    # Third tone (dip)
    "ǎ" => {"a", "3"},
    "ě" => {"e", "3"},
    "ǐ" => {"i", "3"},
    "ǒ" => {"o", "3"},
    "ǔ" => {"u", "3"},
    "ǚ" => {"v", "3"},
    # Fourth tone (falling)
    "à" => {"a", "4"},
    "è" => {"e", "4"},
    "ì" => {"i", "4"},
    "ò" => {"o", "4"},
    "ù" => {"u", "4"},
    "ǜ" => {"v", "4"}
  }

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
    pinyin
    |> String.split(~r/\s+/)
    |> Enum.map(&syllable_to_numbered/1)
    |> Enum.join(" ")
  end

  def to_numbered(nil), do: nil

  defp syllable_to_numbered(syllable) do
    # Find the tone mark and extract the tone number
    {base_syllable, tone} = extract_tone(syllable)

    if tone do
      base_syllable <> tone
    else
      # No tone mark found (neutral tone or already numbered)
      syllable
    end
  end

  defp extract_tone(syllable) do
    syllable
    |> String.graphemes()
    |> Enum.reduce({[], nil}, fn char, {acc, tone} ->
      case Map.get(@tone_marks, char) do
        {base_char, tone_num} ->
          {acc ++ [base_char], tone_num}

        nil ->
          # Handle ü without tone mark
          char = if char == "ü", do: "v", else: char
          {acc ++ [char], tone}
      end
    end)
    |> then(fn {chars, tone} -> {Enum.join(chars), tone} end)
  end

  @doc """
  Normalizes user input pinyin for comparison.

  - Converts to lowercase
  - Normalizes whitespace
  - Handles common variations (v/ü)

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
end

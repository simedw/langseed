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
    # Convert tone marks to numbers
    # Handles both single syllables "hǎo" → "hao3" and multi-syllable words "rúguǒ" → "ru2guo3"
    syllable
    |> String.graphemes()
    |> process_graphemes([])
    |> Enum.reverse()
    |> Enum.join()
  end

  # Process graphemes and place tone numbers correctly
  defp process_graphemes([], acc), do: acc

  defp process_graphemes([char | rest], acc) do
    case Map.get(@tone_marks, char) do
      {base_char, tone_num} ->
        # Found a tone mark - determine where to place the tone number
        # If next char is a consonant or start of new syllable, place tone now
        # Otherwise, continue accumulating
        case detect_syllable_boundary(rest) do
          :boundary ->
            # Syllable boundary detected, append tone immediately
            process_graphemes(rest, [tone_num, base_char | acc])

          :continue ->
            # More vowels in this syllable, hold the tone for later
            place_tone_at_syllable_end(rest, tone_num, [base_char | acc])
        end

      nil ->
        # Regular character or ü
        normalized = if char == "ü", do: "v", else: char
        process_graphemes(rest, [normalized | acc])
    end
  end

  # Check if we're at a syllable boundary
  defp detect_syllable_boundary([next_char | _]) do
    # Consonants (except 'n' and 'r' which can be part of finals) indicate new syllable
    if next_char in [
         "b",
         "c",
         "d",
         "f",
         "g",
         "h",
         "j",
         "k",
         "l",
         "m",
         "p",
         "q",
         "s",
         "t",
         "w",
         "x",
         "y",
         "z"
       ] do
      :boundary
    else
      :continue
    end
  end

  defp detect_syllable_boundary([]), do: :boundary

  # Place tone at the end of current syllable
  defp place_tone_at_syllable_end([], tone_num, acc), do: [tone_num | acc]

  defp place_tone_at_syllable_end([char | rest], tone_num, acc) do
    normalized = if char == "ü", do: "v", else: char

    case Map.get(@tone_marks, char) do
      {_base_char, _} ->
        # Another tone mark, shouldn't happen in same syllable but handle it
        [tone_num, normalized | acc]

      nil ->
        # Check if this is end of syllable
        if detect_syllable_boundary(rest) == :boundary do
          # End of syllable, place tone here
          process_graphemes(rest, [tone_num, normalized | acc])
        else
          # Continue syllable
          place_tone_at_syllable_end(rest, tone_num, [normalized | acc])
        end
    end
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

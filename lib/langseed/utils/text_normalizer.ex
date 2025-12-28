defmodule Langseed.Utils.TextNormalizer do
  @moduledoc """
  Normalizes text for consistent hashing and de-duplication.
  """

  @doc """
  Normalizes text for consistent hashing.
  Removes extra whitespace and normalizes punctuation.
  """
  def normalize_for_hash(text, language) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> normalize_punctuation(language)
  end

  defp normalize_punctuation(text, "zh") do
    # Normalize Chinese punctuation to standard forms
    # Using Unicode codepoints for curly quotes to avoid syntax issues
    text
    |> String.replace("，", ",")
    |> String.replace("。", ".")
    |> String.replace("？", "?")
    |> String.replace("！", "!")
    |> String.replace("：", ":")
    |> String.replace("；", ";")
    |> String.replace("\u201C", "\"")
    |> String.replace("\u201D", "\"")
    |> String.replace("\u2018", "'")
    |> String.replace("\u2019", "'")
  end

  defp normalize_punctuation(text, _), do: text

  @doc """
  Generates a deterministic hash for audio caching.
  The hash is based on the normalized text, language, and voice parameters.
  """
  def generate_audio_hash(text, language, voice_params) do
    normalized = normalize_for_hash(text, language)

    :crypto.hash(:sha256, "#{normalized}:#{language}:#{inspect(voice_params)}")
    |> Base.encode16(case: :lower)
  end
end

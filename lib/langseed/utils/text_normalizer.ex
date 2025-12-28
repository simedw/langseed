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

  Uses a stable serialization for voice_params to ensure consistent hashing
  regardless of map key ordering.
  """
  def generate_audio_hash(text, language, voice_params) do
    normalized = normalize_for_hash(text, language)
    voice_string = serialize_voice_params(voice_params)

    :crypto.hash(:sha256, "#{normalized}:#{language}:#{voice_string}")
    |> Base.encode16(case: :lower)
  end

  # Serialize voice params deterministically by sorting keys and encoding as key=value pairs.
  # This ensures the same logical map always produces the same string representation.
  defp serialize_voice_params(params) when is_map(params) do
    params
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> "#{k}=#{serialize_value(v)}" end)
    |> Enum.join(",")
  end

  defp serialize_voice_params(params), do: to_string(params)

  defp serialize_value(v) when is_map(v), do: "{#{serialize_voice_params(v)}}"
  defp serialize_value(v) when is_list(v), do: "[#{Enum.map_join(v, ",", &serialize_value/1)}]"
  defp serialize_value(v), do: to_string(v)
end

defmodule Langseed.Utils.StringUtils do
  @moduledoc """
  General string utilities that are not language-specific.
  """

  @doc """
  Ensures a string is valid UTF-8, dropping any invalid byte sequences.

  Returns an empty string for nil input.
  """
  @spec ensure_valid_utf8(binary() | nil) :: binary()
  def ensure_valid_utf8(nil), do: ""

  def ensure_valid_utf8(str) when is_binary(str) do
    if String.valid?(str) do
      str
    else
      # Extract only valid UTF-8 portions, dropping invalid bytes
      case :unicode.characters_to_binary(str, :utf8, :utf8) do
        {:error, valid, _} -> valid
        {:incomplete, valid, _} -> valid
        binary when is_binary(binary) -> binary
      end
    end
  end
end

defmodule Langseed.Language do
  @moduledoc """
  Behaviour for language-specific text processing.

  This module defines the interface that any language implementation must provide.
  Currently only Chinese is implemented, but the architecture allows for adding
  other languages in the future.
  """

  @type word :: String.t()
  @type segment ::
          {:word, word()}
          | {:punct, String.t()}
          | {:space, String.t()}
          | {:newline, String.t()}

  @doc "Segments text into words, punctuation, spaces, and newlines"
  @callback segment(text :: String.t()) :: [segment()]

  @doc "Returns true if the grapheme is a valid word character for this language"
  @callback word_char?(grapheme :: String.t()) :: boolean()

  @doc "Extracts individual characters from a set of words"
  @callback extract_chars(words :: MapSet.t()) :: MapSet.t()

  @doc "Finds characters in text that are not in the known_chars set"
  @callback find_unknown_chars(text :: String.t(), known_chars :: MapSet.t()) :: [String.t()]

  # Default implementation dispatches to Chinese
  # This can be made configurable per-user in the future

  @spec segment(String.t()) :: [segment()]
  def segment(text) do
    Langseed.Language.Chinese.segment(text)
  end

  @spec word_char?(String.t()) :: boolean()
  def word_char?(grapheme) do
    Langseed.Language.Chinese.word_char?(grapheme)
  end

  @spec extract_chars(MapSet.t()) :: MapSet.t()
  def extract_chars(words) do
    Langseed.Language.Chinese.extract_chars(words)
  end

  @spec find_unknown_chars(String.t(), MapSet.t()) :: [String.t()]
  def find_unknown_chars(text, known_chars) do
    Langseed.Language.Chinese.find_unknown_chars(text, known_chars)
  end
end

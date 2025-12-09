defmodule Langseed.Language do
  @moduledoc """
  Behaviour for language-specific text processing.

  This module defines the interface that any language implementation must provide.
  Currently supports Chinese, Swedish, and English.
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

  @doc "Finds words in text that are not in the known_words set"
  @callback find_unknown_words(text :: String.t(), known_words :: MapSet.t()) :: [String.t()]

  # Language implementation dispatch

  @spec impl_for(String.t()) :: module()
  def impl_for("zh"), do: Langseed.Language.Chinese
  def impl_for(lang) when lang in ["en", "sv"], do: Langseed.Language.SpaceDelimited
  def impl_for(_), do: Langseed.Language.SpaceDelimited

  @spec segment(String.t(), String.t()) :: [segment()]
  def segment(text, language \\ "zh") do
    impl_for(language).segment(text)
  end

  @spec word_char?(String.t(), String.t()) :: boolean()
  def word_char?(grapheme, language \\ "zh") do
    impl_for(language).word_char?(grapheme)
  end

  @spec extract_chars(MapSet.t(), String.t()) :: MapSet.t()
  def extract_chars(words, language \\ "zh") do
    impl_for(language).extract_chars(words)
  end

  @spec find_unknown_chars(String.t(), MapSet.t(), String.t()) :: [String.t()]
  def find_unknown_chars(text, known_chars, language \\ "zh") do
    impl_for(language).find_unknown_chars(text, known_chars)
  end

  @spec find_unknown_words(String.t(), MapSet.t(), String.t()) :: [String.t()]
  def find_unknown_words(text, known_words, language \\ "zh") do
    impl_for(language).find_unknown_words(text, known_words)
  end
end

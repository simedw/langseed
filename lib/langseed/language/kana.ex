defmodule Langseed.Language.Kana do
  @moduledoc """
  Utilities for working with Japanese kana (hiragana and katakana) readings.

  Handles conversion between hiragana and katakana, normalization for comparison,
  and validation of readings.
  """

  # Hiragana to Katakana mapping (full-width)
  @hiragana_to_katakana %{
    "あ" => "ア",
    "い" => "イ",
    "う" => "ウ",
    "え" => "エ",
    "お" => "オ",
    "か" => "カ",
    "き" => "キ",
    "く" => "ク",
    "け" => "ケ",
    "こ" => "コ",
    "が" => "ガ",
    "ぎ" => "ギ",
    "ぐ" => "グ",
    "げ" => "ゲ",
    "ご" => "ゴ",
    "さ" => "サ",
    "し" => "シ",
    "す" => "ス",
    "せ" => "セ",
    "そ" => "ソ",
    "ざ" => "ザ",
    "じ" => "ジ",
    "ず" => "ズ",
    "ぜ" => "ゼ",
    "ぞ" => "ゾ",
    "た" => "タ",
    "ち" => "チ",
    "つ" => "ツ",
    "て" => "テ",
    "と" => "ト",
    "だ" => "ダ",
    "ぢ" => "ヂ",
    "づ" => "ヅ",
    "で" => "デ",
    "ど" => "ド",
    "な" => "ナ",
    "に" => "ニ",
    "ぬ" => "ヌ",
    "ね" => "ネ",
    "の" => "ノ",
    "は" => "ハ",
    "ひ" => "ヒ",
    "ふ" => "フ",
    "へ" => "ヘ",
    "ほ" => "ホ",
    "ば" => "バ",
    "び" => "ビ",
    "ぶ" => "ブ",
    "べ" => "ベ",
    "ぼ" => "ボ",
    "ぱ" => "パ",
    "ぴ" => "ピ",
    "ぷ" => "プ",
    "ぺ" => "ペ",
    "ぽ" => "ポ",
    "ま" => "マ",
    "み" => "ミ",
    "む" => "ム",
    "め" => "メ",
    "も" => "モ",
    "や" => "ヤ",
    "ゆ" => "ユ",
    "よ" => "ヨ",
    "ら" => "ラ",
    "り" => "リ",
    "る" => "ル",
    "れ" => "レ",
    "ろ" => "ロ",
    "わ" => "ワ",
    "を" => "ヲ",
    "ん" => "ン",
    "ゃ" => "ャ",
    "ゅ" => "ュ",
    "ょ" => "ョ",
    "ぁ" => "ァ",
    "ぃ" => "ィ",
    "ぅ" => "ゥ",
    "ぇ" => "ェ",
    "ぉ" => "ォ",
    "っ" => "ッ",
    "ゎ" => "ヮ",
    "ゐ" => "ヰ",
    "ゑ" => "ヱ",
    "ゔ" => "ヴ",
    "ー" => "ー",
    "　" => "　"
  }

  @katakana_to_hiragana @hiragana_to_katakana
                        |> Enum.map(fn {h, k} -> {k, h} end)
                        |> Enum.into(%{})

  @doc """
  Converts hiragana text to katakana.

  ## Examples

      iex> Langseed.Language.Kana.to_katakana("ひらがな")
      "ヒラガナ"

      iex> Langseed.Language.Kana.to_katakana("こんにちは")
      "コンニチハ"
  """
  @spec to_katakana(String.t()) :: String.t()
  def to_katakana(text) when is_binary(text) do
    text
    |> String.graphemes()
    |> Enum.map(fn char ->
      Map.get(@hiragana_to_katakana, char, char)
    end)
    |> Enum.join()
  end

  def to_katakana(nil), do: nil

  @doc """
  Converts katakana text to hiragana.

  ## Examples

      iex> Langseed.Language.Kana.to_hiragana("カタカナ")
      "かたかな"

      iex> Langseed.Language.Kana.to_hiragana("コンニチハ")
      "こんにちは"
  """
  @spec to_hiragana(String.t()) :: String.t()
  def to_hiragana(text) when is_binary(text) do
    text
    |> String.graphemes()
    |> Enum.map(fn char ->
      Map.get(@katakana_to_hiragana, char, char)
    end)
    |> Enum.join()
  end

  def to_hiragana(nil), do: nil

  @doc """
  Normalizes kana reading for comparison.

  - Converts to hiragana (standardizing on hiragana)
  - Removes whitespace
  - Converts full-width characters to half-width for katakana
  - Lowercases any ASCII characters

  ## Examples

      iex> Langseed.Language.Kana.normalize("コンニチハ")
      "こんにちは"

      iex> Langseed.Language.Kana.normalize("こんにちは　")
      "こんにちは"

      iex> Langseed.Language.Kana.normalize("カタカナ")
      "かたかな"
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(text) when is_binary(text) do
    text
    |> to_hiragana()
    |> String.replace(~r/\s+/, "")
    |> String.downcase()
  end

  def normalize(nil), do: nil

  @doc """
  Checks if two kana readings match (after normalization).

  Accepts both hiragana and katakana input and compares them after
  normalizing to hiragana.

  ## Examples

      iex> Langseed.Language.Kana.match?("こんにちは", "コンニチハ")
      true

      iex> Langseed.Language.Kana.match?("ひらがな", "ひらがな")
      true

      iex> Langseed.Language.Kana.match?("ひらがな", "カタカナ")
      false
  """
  @spec match?(String.t(), String.t()) :: boolean()
  def match?(input, expected) do
    normalize(input) == normalize(expected)
  end

  @doc """
  Checks if text contains only hiragana characters.

  ## Examples

      iex> Langseed.Language.Kana.hiragana?("ひらがな")
      true

      iex> Langseed.Language.Kana.hiragana?("カタカナ")
      false

      iex> Langseed.Language.Kana.hiragana?("漢字")
      false
  """
  @spec hiragana?(String.t()) :: boolean()
  def hiragana?(text) when is_binary(text) do
    Regex.match?(~r/^[\p{Hiragana}\s　]+$/u, text)
  end

  def hiragana?(nil), do: false

  @doc """
  Checks if text contains only katakana characters.

  ## Examples

      iex> Langseed.Language.Kana.katakana?("カタカナ")
      true

      iex> Langseed.Language.Kana.katakana?("ひらがな")
      false

      iex> Langseed.Language.Kana.katakana?("漢字")
      false
  """
  @spec katakana?(String.t()) :: boolean()
  def katakana?(text) when is_binary(text) do
    Regex.match?(~r/^[\p{Katakana}\s　ー]+$/u, text)
  end

  def katakana?(nil), do: false

  @doc """
  Checks if text contains only kana characters (hiragana or katakana).

  ## Examples

      iex> Langseed.Language.Kana.kana?("ひらがな")
      true

      iex> Langseed.Language.Kana.kana?("カタカナ")
      true

      iex> Langseed.Language.Kana.kana?("ひらがなとカタカナ")
      true

      iex> Langseed.Language.Kana.kana?("漢字")
      false
  """
  @spec kana?(String.t()) :: boolean()
  def kana?(text) when is_binary(text) do
    Regex.match?(~r/^[\p{Hiragana}\p{Katakana}\s　ー]+$/u, text)
  end

  def kana?(nil), do: false

  @doc """
  Validates that a reading is in valid kana format.

  Returns `:ok` if valid, `{:error, reason}` otherwise.

  ## Examples

      iex> Langseed.Language.Kana.validate_reading("ひらがな")
      :ok

      iex> Langseed.Language.Kana.validate_reading("カタカナ")
      :ok

      iex> Langseed.Language.Kana.validate_reading("漢字")
      {:error, "Reading must be in hiragana or katakana"}

      iex> Langseed.Language.Kana.validate_reading("")
      {:error, "Reading cannot be empty"}
  """
  @spec validate_reading(String.t() | nil) :: :ok | {:error, String.t()}
  def validate_reading(nil), do: {:error, "Reading cannot be empty"}
  def validate_reading(""), do: {:error, "Reading cannot be empty"}

  def validate_reading(text) when is_binary(text) do
    if kana?(text) do
      :ok
    else
      {:error, "Reading must be in hiragana or katakana"}
    end
  end
end

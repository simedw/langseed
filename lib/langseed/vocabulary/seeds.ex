defmodule Langseed.Vocabulary.Seeds do
  @moduledoc """
  Seed vocabulary for new users - common foundational Chinese words.
  These words serve as building blocks for self-referential explanations.
  """

  @seed_words [
    %{word: "我", pinyin: "wǒ", meaning: "I, me", part_of_speech: "pronoun", explanations: ["👤 (指自己)"], understanding: 100},
    %{word: "你", pinyin: "nǐ", meaning: "you", part_of_speech: "pronoun", explanations: ["👆 (指对方)"], understanding: 100},
    %{word: "他", pinyin: "tā", meaning: "he, him", part_of_speech: "pronoun", explanations: ["👤 不是我，不是你"], understanding: 100},
    %{word: "她", pinyin: "tā", meaning: "she, her", part_of_speech: "pronoun", explanations: ["👩 女的他"], understanding: 100},
    %{word: "是", pinyin: "shì", meaning: "is, am, are", part_of_speech: "verb", explanations: ["= (等于)"], understanding: 100},
    %{word: "不", pinyin: "bù", meaning: "not, no", part_of_speech: "adverb", explanations: ["❌ 没有，不是"], understanding: 100},
    %{word: "有", pinyin: "yǒu", meaning: "have, has", part_of_speech: "verb", explanations: ["🤲 在手里"], understanding: 100},
    %{word: "这", pinyin: "zhè", meaning: "this", part_of_speech: "pronoun", explanations: ["👇 近的"], understanding: 100},
    %{word: "那", pinyin: "nà", meaning: "that", part_of_speech: "pronoun", explanations: ["👉 远的，不是这"], understanding: 100},
    %{word: "什么", pinyin: "shénme", meaning: "what", part_of_speech: "pronoun", explanations: ["❓ 问东西"], understanding: 100},
    %{word: "好", pinyin: "hǎo", meaning: "good", part_of_speech: "adjective", explanations: ["👍 不坏"], understanding: 100},
    %{word: "大", pinyin: "dà", meaning: "big, large", part_of_speech: "adjective", explanations: ["🐘 不小"], understanding: 100},
    %{word: "小", pinyin: "xiǎo", meaning: "small, little", part_of_speech: "adjective", explanations: ["🐜 不大"], understanding: 100},
    %{word: "人", pinyin: "rén", meaning: "person, people", part_of_speech: "noun", explanations: ["👤 我们都是"], understanding: 100},
    %{word: "一", pinyin: "yī", meaning: "one", part_of_speech: "numeral", explanations: ["1️⃣"], understanding: 100},
    %{word: "二", pinyin: "èr", meaning: "two", part_of_speech: "numeral", explanations: ["2️⃣ 一 + 一"], understanding: 100},
    %{word: "三", pinyin: "sān", meaning: "three", part_of_speech: "numeral", explanations: ["3️⃣ 二 + 一"], understanding: 100},
    %{word: "个", pinyin: "gè", meaning: "general measure word", part_of_speech: "measure_word", explanations: ["一个人，一个东西"], understanding: 100},
    %{word: "在", pinyin: "zài", meaning: "at, in, on", part_of_speech: "preposition", explanations: ["📍 地方"], understanding: 100},
    %{word: "的", pinyin: "de", meaning: "possessive particle", part_of_speech: "particle", explanations: ["我的 = 是我的东西"], understanding: 100},
    %{word: "了", pinyin: "le", meaning: "completion particle", part_of_speech: "particle", explanations: ["做好了 ✅"], understanding: 100},
    %{word: "和", pinyin: "hé", meaning: "and, with", part_of_speech: "conjunction", explanations: ["➕ 一起"], understanding: 100},
    %{word: "很", pinyin: "hěn", meaning: "very", part_of_speech: "adverb", explanations: ["好 → 很好 👍👍"], understanding: 100},
    %{word: "吃", pinyin: "chī", meaning: "eat", part_of_speech: "verb", explanations: ["🍚 → 👄"], understanding: 100},
    %{word: "喝", pinyin: "hē", meaning: "drink", part_of_speech: "verb", explanations: ["🥤 → 👄"], understanding: 100},
    %{word: "看", pinyin: "kàn", meaning: "look, see, watch", part_of_speech: "verb", explanations: ["👀"], understanding: 100},
    %{word: "说", pinyin: "shuō", meaning: "say, speak", part_of_speech: "verb", explanations: ["👄💬"], understanding: 100},
    %{word: "想", pinyin: "xiǎng", meaning: "think, want, miss", part_of_speech: "verb", explanations: ["🧠💭"], understanding: 100},
    %{word: "去", pinyin: "qù", meaning: "go", part_of_speech: "verb", explanations: ["🚶 这 → 那"], understanding: 100},
    %{word: "来", pinyin: "lái", meaning: "come", part_of_speech: "verb", explanations: ["🚶 那 → 这"], understanding: 100},
  ]

  @doc """
  Returns the list of seed word attributes.
  """
  def seed_words, do: @seed_words

  @doc """
  Creates seed vocabulary for a new user.
  Returns {:ok, count} with number of words created.
  """
  def create_for_user(user) do
    alias Langseed.Vocabulary

    results =
      @seed_words
      |> Enum.map(fn attrs ->
        # Add default values
        attrs = Map.merge(attrs, %{
          explanation_quality: 5,
          desired_words: [],
          example_sentence: nil
        })

        Vocabulary.create_concept(user, attrs)
      end)

    successful = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)

    {:ok, successful}
  end
end

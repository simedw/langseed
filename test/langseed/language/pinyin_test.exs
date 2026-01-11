defmodule Langseed.Language.PinyinTest do
  use ExUnit.Case, async: true

  alias Langseed.Language.Pinyin

  describe "to_numbered/1" do
    test "converts tone-marked pinyin to numbered" do
      assert Pinyin.to_numbered("nǐ hǎo") == "ni3 hao3"
      assert Pinyin.to_numbered("tāo qì") == "tao1 qi4"
      assert Pinyin.to_numbered("ài") == "ai4"
      assert Pinyin.to_numbered("suǒ yǐ") == "suo3 yi3"
    end

    test "handles already-numbered pinyin" do
      assert Pinyin.to_numbered("ni3 hao3") == "ni3 hao3"
      assert Pinyin.to_numbered("ru2guo3") == "ru2guo3"
      assert Pinyin.to_numbered("tao1 qi4") == "tao1 qi4"
    end

    test "handles nil" do
      assert Pinyin.to_numbered(nil) == nil
    end
  end

  describe "normalize/1" do
    test "normalizes pinyin by converting to lowercase and numbered format" do
      assert Pinyin.normalize("Ni3 Hao3") == "ni3hao3"
      assert Pinyin.normalize("nǚ") == "nv3"
    end

    test "handles already-numbered pinyin correctly" do
      # This test will reveal the bug
      assert Pinyin.normalize("ru2guo3") == "ru2guo3"
      assert Pinyin.normalize("ni3hao3") == "ni3hao3"
      assert Pinyin.normalize("tao1 qi4") == "tao1qi4"
    end

    test "handles numbered pinyin without spaces" do
      # User reported: typing "ru2guo3" showed as "ruguo3" - now fixed
      result = Pinyin.normalize("ru2guo3")
      assert result == "ru2guo3"
      assert String.contains?(result, "2")
    end

    test "handles nil" do
      assert Pinyin.normalize(nil) == nil
    end
  end

  describe "match?/2" do
    test "matches pinyin strings after normalization" do
      assert Pinyin.match?("ni3hao3", "nǐ hǎo")
      assert Pinyin.match?("ni3hao3", "ni3 hao3")
      assert Pinyin.match?("Ni3 Hao3", "nǐ hǎo")
    end

    test "matches already-numbered input" do
      assert Pinyin.match?("ru2guo3", "rúguǒ")
      assert Pinyin.match?("ru2guo3", "ru2 guo3")
    end
  end

  describe "syllables_with_tones/1" do
    test "parses basic pinyin syllables" do
      assert Pinyin.syllables_with_tones("nǐ hǎo") == [{"nǐ", 3}, {"hǎo", 3}]
      assert Pinyin.syllables_with_tones("tāo qì") == [{"tāo", 1}, {"qì", 4}]
    end

    test "parses compound pinyin without spaces" do
      assert Pinyin.syllables_with_tones("rúguǒ") == [{"rú", 2}, {"guǒ", 3}]
    end

    test "handles neutral tone" do
      assert Pinyin.syllables_with_tones("de") == [{"de", 0}]
    end

    test "handles apostrophe separators" do
      # Apostrophes are used in pinyin to separate syllables (e.g., 亲爱 = qīn'ài)
      result = Pinyin.syllables_with_tones("qīn'ài")
      assert result == [{"qīn", 1}, {"ài", 4}]
    end

    test "handles nil" do
      assert Pinyin.syllables_with_tones(nil) == []
    end
  end
end

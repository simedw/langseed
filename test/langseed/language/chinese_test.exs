defmodule Langseed.Language.ChineseTest do
  use ExUnit.Case, async: true

  alias Langseed.Language.Chinese

  describe "word_char?/1" do
    test "returns true for CJK characters" do
      assert Chinese.word_char?("你")
      assert Chinese.word_char?("好")
      assert Chinese.word_char?("中")
      assert Chinese.word_char?("文")
    end

    test "returns false for English letters" do
      refute Chinese.word_char?("a")
      refute Chinese.word_char?("Z")
    end

    test "returns false for numbers" do
      refute Chinese.word_char?("1")
      refute Chinese.word_char?("9")
    end

    test "returns false for punctuation" do
      refute Chinese.word_char?("。")
      refute Chinese.word_char?("!")
      refute Chinese.word_char?(",")
    end

    test "returns false for emojis" do
      refute Chinese.word_char?("👋")
      refute Chinese.word_char?("😊")
    end
  end

  describe "extract_chars/1" do
    test "extracts Chinese characters from words" do
      words = MapSet.new(["你好", "世界"])
      chars = Chinese.extract_chars(words)

      assert MapSet.member?(chars, "你")
      assert MapSet.member?(chars, "好")
      assert MapSet.member?(chars, "世")
      assert MapSet.member?(chars, "界")
      assert MapSet.size(chars) == 4
    end

    test "ignores non-Chinese characters" do
      words = MapSet.new(["hello", "123"])
      chars = Chinese.extract_chars(words)

      assert MapSet.size(chars) == 0
    end

    test "handles empty set" do
      assert Chinese.extract_chars(MapSet.new()) == MapSet.new()
    end
  end

  describe "find_unknown_chars/2" do
    test "finds characters not in known set" do
      known_chars = MapSet.new(["你", "好"])
      text = "你好世界"

      unknown = Chinese.find_unknown_chars(text, known_chars)
      assert "世" in unknown
      assert "界" in unknown
      refute "你" in unknown
      refute "好" in unknown
    end

    test "returns empty list when all chars are known" do
      known_chars = MapSet.new(["你", "好"])
      text = "你好"

      assert Chinese.find_unknown_chars(text, known_chars) == []
    end

    test "detects English letters and adds marker" do
      known_chars = MapSet.new(["你", "好"])
      text = "你好 hello"

      unknown = Chinese.find_unknown_chars(text, known_chars)
      assert "[英文]" in unknown
    end

    test "ignores punctuation and emojis" do
      known_chars = MapSet.new(["你", "好"])
      text = "你好！👋"

      assert Chinese.find_unknown_chars(text, known_chars) == []
    end
  end

  describe "segment/1" do
    test "segments Chinese text into words" do
      segments = Chinese.segment("你好世界")

      assert is_list(segments)
      refute Enum.empty?(segments)

      words =
        segments
        |> Enum.filter(fn
          {:word, _} -> true
          _ -> false
        end)
        |> Enum.map(fn {:word, w} -> w end)

      # Should have segmented into words
      refute Enum.empty?(words)
    end

    test "preserves newlines" do
      segments = Chinese.segment("你好\n世界")

      newlines =
        Enum.filter(segments, fn
          {:newline, _} -> true
          _ -> false
        end)

      assert length(newlines) == 1
    end

    test "identifies punctuation" do
      segments = Chinese.segment("你好！")

      puncts =
        Enum.filter(segments, fn
          {:punct, _} -> true
          _ -> false
        end)

      refute Enum.empty?(puncts)
    end
  end
end

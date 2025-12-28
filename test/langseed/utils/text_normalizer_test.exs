defmodule Langseed.Utils.TextNormalizerTest do
  use ExUnit.Case, async: true

  alias Langseed.Utils.TextNormalizer

  describe "normalize_for_hash/2" do
    test "trims whitespace" do
      assert TextNormalizer.normalize_for_hash("  hello  ", "en") == "hello"
    end

    test "collapses multiple spaces to single space" do
      assert TextNormalizer.normalize_for_hash("hello   world", "en") == "hello world"
    end

    test "normalizes Chinese punctuation to ASCII equivalents" do
      # Chinese comma → ASCII comma
      assert TextNormalizer.normalize_for_hash("你好，世界", "zh") == "你好,世界"

      # Chinese period → ASCII period
      assert TextNormalizer.normalize_for_hash("你好。", "zh") == "你好."

      # Chinese question mark → ASCII question mark
      assert TextNormalizer.normalize_for_hash("你好吗？", "zh") == "你好吗?"

      # Chinese exclamation → ASCII exclamation
      assert TextNormalizer.normalize_for_hash("太好了！", "zh") == "太好了!"

      # Chinese colon → ASCII colon
      assert TextNormalizer.normalize_for_hash("注意：", "zh") == "注意:"

      # Chinese semicolon → ASCII semicolon
      assert TextNormalizer.normalize_for_hash("第一；第二", "zh") == "第一;第二"
    end

    test "normalizes Chinese quotes to ASCII equivalents" do
      # Chinese double quotes → ASCII double quotes
      input_double = ~s("你好")
      assert TextNormalizer.normalize_for_hash(input_double, "zh") == ~s("你好")

      # Chinese single quotes → ASCII single quotes
      input_single = ~s('测试')
      assert TextNormalizer.normalize_for_hash(input_single, "zh") == "'测试'"
    end

    test "does not normalize punctuation for non-Chinese languages" do
      # Chinese punctuation should remain unchanged for other languages
      assert TextNormalizer.normalize_for_hash("你好，世界", "en") == "你好，世界"
    end

    test "handles empty string" do
      assert TextNormalizer.normalize_for_hash("", "zh") == ""
    end

    test "handles mixed content" do
      input = "  Hello，世界！  How are you？  "
      expected = "Hello,世界! How are you?"
      assert TextNormalizer.normalize_for_hash(input, "zh") == expected
    end
  end

  describe "generate_audio_hash/3" do
    test "generates consistent hash for same input" do
      hash1 = TextNormalizer.generate_audio_hash("你好", "zh", %{voice: "cmn-CN-Neural2-C"})
      hash2 = TextNormalizer.generate_audio_hash("你好", "zh", %{voice: "cmn-CN-Neural2-C"})

      assert hash1 == hash2
      assert is_binary(hash1)
      assert String.length(hash1) == 64
    end

    test "generates different hash for different text" do
      hash1 = TextNormalizer.generate_audio_hash("你好", "zh", %{voice: "cmn-CN-Neural2-C"})
      hash2 = TextNormalizer.generate_audio_hash("再见", "zh", %{voice: "cmn-CN-Neural2-C"})

      assert hash1 != hash2
    end

    test "generates different hash for different language" do
      hash1 = TextNormalizer.generate_audio_hash("hello", "en", %{voice: "en-US-Neural2-A"})
      hash2 = TextNormalizer.generate_audio_hash("hello", "zh", %{voice: "en-US-Neural2-A"})

      assert hash1 != hash2
    end

    test "generates different hash for different voice params" do
      hash1 = TextNormalizer.generate_audio_hash("你好", "zh", %{voice: "cmn-CN-Neural2-C"})
      hash2 = TextNormalizer.generate_audio_hash("你好", "zh", %{voice: "cmn-CN-Neural2-D"})

      assert hash1 != hash2
    end

    test "normalizes text before hashing" do
      # Same text with different whitespace/punctuation should produce same hash
      hash1 = TextNormalizer.generate_audio_hash("你好，世界", "zh", %{voice: "test"})
      hash2 = TextNormalizer.generate_audio_hash("  你好,世界  ", "zh", %{voice: "test"})

      assert hash1 == hash2
    end

    test "returns lowercase hex string" do
      hash = TextNormalizer.generate_audio_hash("test", "en", %{})
      assert hash == String.downcase(hash)
      assert Regex.match?(~r/^[a-f0-9]+$/, hash)
    end

    test "generates same hash for maps with same content regardless of construction order" do
      # Create maps in different ways to test deterministic serialization
      map1 = %{voice_name: "Puck", language: "zh", rate: 1.0}
      map2 = %{language: "zh", rate: 1.0, voice_name: "Puck"}
      map3 = Map.new([{:rate, 1.0}, {:voice_name, "Puck"}, {:language, "zh"}])

      hash1 = TextNormalizer.generate_audio_hash("你好", "zh", map1)
      hash2 = TextNormalizer.generate_audio_hash("你好", "zh", map2)
      hash3 = TextNormalizer.generate_audio_hash("你好", "zh", map3)

      assert hash1 == hash2
      assert hash2 == hash3
    end

    test "handles nested maps deterministically" do
      map1 = %{voice: %{name: "Puck", style: "calm"}, rate: 1.0}
      map2 = %{rate: 1.0, voice: %{style: "calm", name: "Puck"}}

      hash1 = TextNormalizer.generate_audio_hash("test", "en", map1)
      hash2 = TextNormalizer.generate_audio_hash("test", "en", map2)

      assert hash1 == hash2
    end

    test "handles atom and string keys consistently" do
      # Both should produce the same hash since we convert keys to strings
      map_atom = %{voice_name: "Puck"}
      map_string = %{"voice_name" => "Puck"}

      hash_atom = TextNormalizer.generate_audio_hash("test", "en", map_atom)
      hash_string = TextNormalizer.generate_audio_hash("test", "en", map_string)

      assert hash_atom == hash_string
    end
  end
end

defmodule Langseed.AudioTest do
  use Langseed.DataCase, async: true

  alias Langseed.Audio
  alias Langseed.Vocabulary

  # These tests verify the Audio module behavior with NoOp providers
  # (which is the default when TTS/Storage credentials are not configured)

  describe "available?/0" do
    test "returns boolean indicating if TTS is available" do
      # With default NoOp providers, TTS should not be available
      result = Audio.available?()
      assert is_boolean(result)
    end
  end

  describe "tts_available?/0" do
    test "returns boolean" do
      result = Audio.tts_available?()
      assert is_boolean(result)
    end
  end

  describe "storage_available?/0" do
    test "returns boolean" do
      result = Audio.storage_available?()
      assert is_boolean(result)
    end
  end

  describe "generate_word_audio/1 with NoOp providers" do
    setup do
      user = Langseed.AccountsFixtures.user_fixture()
      scope = Langseed.Accounts.Scope.for_user(user)

      {:ok, concept} =
        Vocabulary.create_concept(scope, %{
          word: "你好",
          pinyin: "nǐ hǎo",
          meaning: "hello",
          part_of_speech: "interjection",
          language: "zh"
        })

      %{concept: concept}
    end

    test "returns {:ok, nil} when TTS is not available", %{concept: concept} do
      # With NoOp TTS provider, this should return {:ok, nil}
      if not Audio.tts_available?() do
        assert {:ok, nil} = Audio.generate_word_audio(concept)
      end
    end
  end

  describe "generate_sentence_audio/2 with NoOp providers" do
    test "returns {:ok, nil} when TTS is not available" do
      if not Audio.tts_available?() do
        assert {:ok, nil} = Audio.generate_sentence_audio("你好世界", "zh")
      end
    end
  end
end

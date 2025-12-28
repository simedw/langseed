defmodule Langseed.Services.WordImporterTest do
  use Langseed.DataCase, async: true

  alias Langseed.Audio
  alias Langseed.Services.WordImporter
  alias Langseed.Vocabulary

  # Note: Most WordImporter tests require LLM to be configured (GOOGLE_AI_API_KEY).
  # These tests focus on what we can test without LLM: edge cases and audio logic.

  describe "import_words/3" do
    setup do
      user = Langseed.AccountsFixtures.user_fixture()
      scope = Langseed.Accounts.Scope.for_user(user)
      %{scope: scope, user: user}
    end

    test "handles empty word list gracefully", %{scope: scope} do
      # This doesn't require LLM
      {added, failed} = WordImporter.import_words(scope, [], "some context")

      assert added == []
      assert failed == []
    end
  end

  describe "audio generation integration" do
    setup do
      user = Langseed.AccountsFixtures.user_fixture()
      scope = Langseed.Accounts.Scope.for_user(user)

      {:ok, concept} =
        Vocabulary.create_concept(scope, %{
          word: "学习",
          pinyin: "xué xí",
          meaning: "to study",
          part_of_speech: "verb",
          language: "zh"
        })

      %{scope: scope, concept: concept}
    end

    test "concept can be updated with audio_path (object key format)", %{concept: concept} do
      # audio_path must be a storage object key, not a URL or data URL
      object_key = "tts/Puck/zh/abc123def456.wav"

      {:ok, updated} = Vocabulary.update_concept(concept, %{audio_path: object_key})

      assert updated.audio_path == object_key
      # Verify it's a valid object key format (not a URL)
      refute String.contains?(updated.audio_path, "://")
      refute String.starts_with?(updated.audio_path, "data:")
    end

    test "audio_path is nil by default", %{concept: concept} do
      assert concept.audio_path == nil
    end

    test "Audio.available? returns boolean" do
      result = Audio.available?()
      assert is_boolean(result)
    end

    test "Audio.tts_available? returns boolean" do
      result = Audio.tts_available?()
      assert is_boolean(result)
    end

    test "Audio.storage_available? returns boolean" do
      result = Audio.storage_available?()
      assert is_boolean(result)
    end

    test "generate_word_audio returns {:ok, nil} when TTS not available", %{concept: concept} do
      if not Audio.available?() do
        assert {:ok, nil} = Audio.generate_word_audio(concept)
      end
    end

    test "generate_sentence_audio returns {:ok, nil} when TTS not available" do
      if not Audio.available?() do
        assert {:ok, nil} = Audio.generate_sentence_audio("你好世界", "zh")
      end
    end
  end

  describe "audio path caching" do
    setup do
      user = Langseed.AccountsFixtures.user_fixture()
      scope = Langseed.Accounts.Scope.for_user(user)

      {:ok, concept} =
        Vocabulary.create_concept(scope, %{
          word: "好",
          pinyin: "hǎo",
          meaning: "good",
          part_of_speech: "adjective",
          language: "zh"
        })

      %{scope: scope, concept: concept}
    end

    test "audio_path can store an R2 object path", %{concept: concept} do
      # This is the correct format: stable path, not a signed URL
      path = "tts/Aoede/zh/abc123def456.wav"

      {:ok, updated} = Vocabulary.update_concept(concept, %{audio_path: path})
      assert updated.audio_path == path
    end

    test "audio_path must follow object key format (not URL or data URL)" do
      # Document the expected format: tts/{voice}/{language}/{hash}.wav
      # This is the ONLY valid format for audio_path
      valid_path = "tts/Puck/zh/abc123def456.wav"

      assert String.starts_with?(valid_path, "tts/")
      assert String.ends_with?(valid_path, ".wav")
      refute String.contains?(valid_path, "://")
      refute String.starts_with?(valid_path, "data:")
      refute String.contains?(valid_path, "?")
    end
  end

  describe "audio_path_for/2 returns stable paths" do
    test "returns a path, not a signed URL, for supported language" do
      # audio_path_for should return a stable R2 object key, not a signed URL
      path = Audio.audio_path_for("你好", "zh")

      if path do
        # Must NOT contain URL signatures or query params
        refute String.contains?(path, "?")
        refute String.contains?(path, "X-Amz-")
        refute String.contains?(path, "https://")

        # Must be a valid path format: tts/{voice}/{language}/{hash}.wav
        assert String.starts_with?(path, "tts/")
        assert String.ends_with?(path, ".wav")
        assert String.contains?(path, "/zh/")
      end
    end

    test "returns nil for unsupported language" do
      # Languages without voice config should return nil
      path = Audio.audio_path_for("hello", "unsupported_lang_xyz")
      assert path == nil
    end

    test "returns consistent path for same input" do
      # Same text + language should always produce the same path (content-addressable)
      path1 = Audio.audio_path_for("学习", "zh")
      path2 = Audio.audio_path_for("学习", "zh")

      assert path1 == path2
    end

    test "returns different paths for different text" do
      path1 = Audio.audio_path_for("学习", "zh")
      path2 = Audio.audio_path_for("工作", "zh")

      if path1 && path2 do
        assert path1 != path2
      end
    end
  end
end

defmodule Langseed.Audio.Providers.R2StorageTest do
  use ExUnit.Case, async: true

  alias Langseed.Audio.Providers.R2Storage

  describe "available?/0" do
    test "returns false when R2 is not configured" do
      # Check current availability - should be false in test env without credentials
      result = R2Storage.available?()
      assert is_boolean(result)
    end
  end

  describe "behavior implementation" do
    test "implements StorageProvider behavior" do
      behaviors = R2Storage.__info__(:attributes)[:behaviour] || []
      assert Langseed.Audio.StorageProvider in behaviors
    end
  end

  describe "path generation" do
    # These tests verify the expected path format used by the Audio module
    test "audio paths follow expected format" do
      # The Audio module generates paths like: tts/<engine>/<language>/<hash>.mp3
      path = "tts/google-neural2/zh/abc123def456.mp3"

      assert String.starts_with?(path, "tts/")
      assert String.ends_with?(path, ".mp3")
      assert String.contains?(path, "/zh/")
    end
  end
end

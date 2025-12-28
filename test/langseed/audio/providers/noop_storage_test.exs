defmodule Langseed.Audio.Providers.NoopStorageTest do
  use ExUnit.Case, async: true

  alias Langseed.Audio.Providers.NoopStorage

  describe "available?/0" do
    test "returns false" do
      assert NoopStorage.available?() == false
    end
  end

  describe "store_audio/3" do
    test "returns error tuple" do
      assert {:error, :not_configured} =
               NoopStorage.store_audio(<<1, 2, 3>>, "path/to/file.wav", "audio/wav")
    end

    test "works with any input" do
      assert {:error, :not_configured} = NoopStorage.store_audio("", "", "audio/wav")
      assert {:error, :not_configured} = NoopStorage.store_audio(<<>>, "test.wav", "audio/wav")
    end
  end

  describe "audio_exists?/1" do
    test "always returns false" do
      assert NoopStorage.audio_exists?("any/path.mp3") == false
      assert NoopStorage.audio_exists?("") == false
      assert NoopStorage.audio_exists?("tts/google/zh/abc123.mp3") == false
    end
  end

  describe "get_signed_url/2" do
    test "returns error tuple" do
      assert {:error, :not_configured} = NoopStorage.get_signed_url("path.mp3", 3600)
    end

    test "works with any expiry" do
      assert {:error, :not_configured} = NoopStorage.get_signed_url("file.mp3", 0)
      assert {:error, :not_configured} = NoopStorage.get_signed_url("file.mp3", 86_400)
    end
  end
end

defmodule Langseed.Audio.Providers.NoopTTSTest do
  use ExUnit.Case, async: true

  alias Langseed.Audio.Providers.NoopTTS

  describe "available?/0" do
    test "returns false" do
      assert NoopTTS.available?() == false
    end
  end

  describe "generate_audio/3" do
    test "returns error tuple" do
      assert {:error, :not_configured} = NoopTTS.generate_audio("hello", "en", %{})
    end

    test "works with any input" do
      assert {:error, :not_configured} = NoopTTS.generate_audio("你好", "zh", %{voice: "test"})
      assert {:error, :not_configured} = NoopTTS.generate_audio("", "", %{})
    end
  end

  describe "voice_for_language/1" do
    test "returns nil for any language" do
      assert NoopTTS.voice_for_language("en") == nil
      assert NoopTTS.voice_for_language("zh") == nil
      assert NoopTTS.voice_for_language("fr") == nil
    end
  end
end

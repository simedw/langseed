defmodule Langseed.Audio.Providers.GoogleTTSTest do
  use ExUnit.Case, async: true

  alias Langseed.Audio.Providers.GoogleTTS

  describe "voice_for_language/1" do
    test "returns Chinese voice config for 'zh'" do
      config = GoogleTTS.voice_for_language("zh")

      # Gemini TTS uses voice_name instead of separate language_code/ssml_gender
      assert config.voice_name == "Puck"
    end

    test "returns nil for unsupported languages" do
      assert GoogleTTS.voice_for_language("en") == nil
      assert GoogleTTS.voice_for_language("fr") == nil
      assert GoogleTTS.voice_for_language("") == nil
    end
  end

  describe "available?/0" do
    test "returns false when API key is not configured" do
      # Clear any existing config for this test
      original = Application.get_env(:langseed, :google_ai_api_key)
      Application.put_env(:langseed, :google_ai_api_key, nil)

      refute GoogleTTS.available?()

      # Restore original config
      if original do
        Application.put_env(:langseed, :google_ai_api_key, original)
      end
    end
  end

  describe "generate_audio/3" do
    test "returns error when API key is not configured" do
      original = Application.get_env(:langseed, :google_ai_api_key)
      Application.put_env(:langseed, :google_ai_api_key, nil)

      voice_config = GoogleTTS.voice_for_language("zh")
      result = GoogleTTS.generate_audio("你好", "zh", voice_config)

      assert {:error, :not_configured} = result

      # Restore original config
      if original do
        Application.put_env(:langseed, :google_ai_api_key, original)
      end
    end
  end

  describe "behavior implementation" do
    test "implements TTSProvider behavior" do
      behaviors = GoogleTTS.__info__(:attributes)[:behaviour] || []
      assert Langseed.Audio.TTSProvider in behaviors
    end
  end
end

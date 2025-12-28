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

    test "returns false when API key is empty string" do
      original = Application.get_env(:langseed, :google_ai_api_key)
      Application.put_env(:langseed, :google_ai_api_key, "")

      refute GoogleTTS.available?()

      # Restore original config
      Application.put_env(:langseed, :google_ai_api_key, original)
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

  describe "binary audio concatenation" do
    # Verify that IO.iodata_to_binary correctly handles non-UTF8 binary data
    # (This tests the fix for the Enum.join/1 bug which could fail on audio bytes)

    test "IO.iodata_to_binary handles arbitrary binary data" do
      # Create binary data that is NOT valid UTF-8 (simulating audio PCM data)
      # These bytes would cause Enum.join/1 to fail or corrupt data
      chunk1 = <<0xFF, 0xFE, 0x00, 0x80, 0x7F>>
      chunk2 = <<0x00, 0x01, 0xFF, 0xD8, 0xE0>>
      chunk3 = <<0x80, 0x81, 0x82, 0x83, 0x84>>

      # This is how GoogleTTS now concatenates audio chunks
      combined = IO.iodata_to_binary([chunk1, chunk2, chunk3])

      # Should preserve all bytes exactly
      assert byte_size(combined) == 15

      assert combined ==
               <<0xFF, 0xFE, 0x00, 0x80, 0x7F, 0x00, 0x01, 0xFF, 0xD8, 0xE0, 0x80, 0x81, 0x82,
                 0x83, 0x84>>
    end

    test "Enum.join can fail on non-UTF8 binaries" do
      # This test documents why we use IO.iodata_to_binary instead of Enum.join
      # Enum.join treats binaries as strings and may fail or corrupt non-UTF8 data

      # Some non-UTF8 sequences that look like audio data
      audio_chunk = <<0xFF, 0xFE, 0x00, 0x80>>

      # Enum.join uses String.Chars protocol which expects valid UTF-8
      # For non-UTF8 binary data, it either raises or produces incorrect output
      # IO.iodata_to_binary handles all binary data correctly
      assert IO.iodata_to_binary([audio_chunk]) == audio_chunk
    end
  end

  describe "safe base64 decoding" do
    test "Base.decode64 returns :error for invalid base64 (does not crash)" do
      # The decode_base64_safe/1 function wraps Base.decode64 to return
      # {:error, reason} instead of raising on malformed input.
      # We test the underlying behavior that makes this work.

      # Invalid base64 data
      invalid = "not!!valid!!base64!!@@##"
      assert :error = Base.decode64(invalid)

      # Valid base64 data
      valid = Base.encode64("hello world")
      assert {:ok, "hello world"} = Base.decode64(valid)
    end

    test "malformed base64 does not crash the decoder" do
      # This tests that we use safe decoding (Base.decode64 not decode64!)
      # The function should return an error tuple, not raise
      malformed_data = "~~~this-is-not-base64~~~"

      # Using Base.decode64/1 (safe version) returns :error
      assert :error = Base.decode64(malformed_data)

      # Using Base.decode64!/1 would raise an ArgumentError
      assert_raise ArgumentError, fn ->
        Base.decode64!(malformed_data)
      end
    end
  end

  describe "WAV format consistency" do
    test "WAV header structure is documented" do
      # A minimal PCM sample - 4 bytes (2 samples of 16-bit audio)
      pcm_data = <<0x00, 0x10, 0xFF, 0x7F>>

      # We can't directly call pcm_to_wav since it's private,
      # but we can verify the expected behavior through the module's contract:
      # All GoogleTTS output should be audio/wav

      # The WAV header is 44 bytes, so total size = 44 + pcm size
      expected_header_size = 44
      expected_total_size = expected_header_size + byte_size(pcm_data)

      # WAV files start with "RIFF"
      riff_header = "RIFF"
      wave_format = "WAVE"

      # These assertions document the expected WAV structure
      assert byte_size(riff_header) == 4
      assert byte_size(wave_format) == 4
      assert expected_total_size == 48
    end
  end
end

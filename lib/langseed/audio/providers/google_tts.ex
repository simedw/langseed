defmodule Langseed.Audio.Providers.GoogleTTS do
  @moduledoc """
  Gemini Text-to-Speech provider.

  Uses the Gemini 2.5 Pro Preview TTS model to generate audio.
  Reuses the existing GOOGLE_AI_API_KEY environment variable.
  """

  @behaviour Langseed.Audio.TTSProvider

  @model_id "gemini-2.5-pro-preview-tts"
  @tts_endpoint "https://generativelanguage.googleapis.com/v1beta/models/#{@model_id}:streamGenerateContent"

  # Available voices: Zephyr, Puck, Charon, Kore, Fenrir, Leda, Orus, Aoede
  @default_voice "Puck"

  @impl true
  def available?() do
    # Check for both nil and empty string to be defensive
    case get_api_key() do
      nil -> false
      "" -> false
      _key -> true
    end
  end

  @impl true
  def generate_audio(text, _language, voice_config) do
    with {:ok, api_key} <- get_api_key_or_error(),
         request_body = build_request_body(text, voice_config),
         {:ok, %{status: 200, body: body}} <-
           Req.post("#{@tts_endpoint}?key=#{api_key}",
             json: request_body,
             receive_timeout: 60_000
           ) do
      extract_audio_from_response(body)
    else
      {:error, :not_configured} ->
        {:error, :not_configured}

      {:ok, %{status: status, body: body}} ->
        {:error, "TTS API error: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, "TTS request failed: #{inspect(reason)}"}
    end
  end

  defp get_api_key_or_error do
    case get_api_key() do
      nil -> {:error, :not_configured}
      "" -> {:error, :not_configured}
      key -> {:ok, key}
    end
  end

  @impl true
  def voice_for_language("zh") do
    %{
      voice_name: @default_voice
    }
  end

  def voice_for_language("ja") do
    %{
      voice_name: "Kore"
    }
  end

  def voice_for_language("en") do
    %{
      voice_name: "Kore"
    }
  end

  def voice_for_language("sv") do
    %{
      voice_name: "Kore"
    }
  end

  def voice_for_language(_), do: nil

  defp build_request_body(text, voice_config) do
    voice_name = voice_config[:voice_name] || @default_voice

    # Wrap short text in a speech instruction to help the model
    speech_text = """
    STYLE: A teacher, teaching in a classroom. Slow and clear. Standard pronunciation. Sometimes a single word, sometimes a sentence.
    TRANSCRIPT: #{text}
    """

    %{
      contents: [
        %{
          role: "user",
          parts: [
            %{text: speech_text}
          ]
        }
      ],
      generationConfig: %{
        responseModalities: ["AUDIO"],
        speechConfig: %{
          voiceConfig: %{
            prebuiltVoiceConfig: %{
              voiceName: voice_name
            }
          }
        }
      }
    }
  end

  # Gemini streaming response returns an array of chunks
  # Each chunk may contain audio data in inlineData
  # Always returns audio/wav to ensure consistency with storage keys.
  defp extract_audio_from_response(body) when is_list(body) do
    audio_parts =
      body
      |> Enum.flat_map(fn chunk ->
        get_in(chunk, ["candidates", Access.at(0), "content", "parts"]) || []
      end)
      |> Enum.filter(&Map.has_key?(&1, "inlineData"))

    if Enum.empty?(audio_parts) do
      {:error, "No audio data in response"}
    else
      # Get MIME type from first chunk
      mime_type = get_in(hd(audio_parts), ["inlineData", "mimeType"]) || "audio/wav"

      # Combine all audio chunks and decode from base64
      # Use IO.iodata_to_binary for binary-safe concatenation (audio may contain non-UTF8 bytes)
      combined_audio =
        audio_parts
        |> Enum.map(fn part -> part["inlineData"]["data"] end)
        |> Enum.map(&decode_base64_safe/1)
        |> collect_decoded_chunks()

      case combined_audio do
        {:error, reason} ->
          {:error, reason}

        {:ok, audio_binary} ->
          # Convert to WAV - Gemini typically returns L16 PCM which needs a WAV header.
          # Always output audio/wav to match storage key expectations.
          normalize_to_wav(audio_binary, mime_type)
      end
    end
  end

  defp extract_audio_from_response(body) do
    {:error, "Unexpected response format: #{inspect(body)}"}
  end

  # Safely decode base64 without raising
  defp decode_base64_safe(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, "Invalid base64 data in audio chunk"}
    end
  end

  # Collect decoded chunks, returning error if any failed
  defp collect_decoded_chunks(results) do
    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, reason} ->
        {:error, reason}

      nil ->
        binary =
          results
          |> Enum.map(fn {:ok, data} -> data end)
          |> IO.iodata_to_binary()

        {:ok, binary}
    end
  end

  # Normalize audio to WAV format for consistent storage and playback.
  defp normalize_to_wav(audio_binary, mime_type) do
    cond do
      # L16 PCM needs a WAV header
      String.starts_with?(mime_type, "audio/L16") or String.starts_with?(mime_type, "audio/l16") ->
        sample_rate = parse_sample_rate(mime_type)
        wav_data = pcm_to_wav(audio_binary, sample_rate)
        {:ok, wav_data, "audio/wav"}

      # Already WAV - pass through
      mime_type == "audio/wav" or mime_type == "audio/wave" ->
        {:ok, audio_binary, "audio/wav"}

      # Unknown format - return as-is but label as wav (storage keys are .wav)
      # This is a fallback; Gemini TTS should always return L16 PCM.
      true ->
        require Logger
        Logger.warning("Unexpected TTS MIME type: #{mime_type}, returning as audio/wav")
        {:ok, audio_binary, "audio/wav"}
    end
  end

  # Parse sample rate from MIME type like "audio/L16;rate=24000"
  defp parse_sample_rate(mime_type) do
    case Regex.run(~r/rate=(\d+)/, mime_type) do
      [_, rate] -> String.to_integer(rate)
      _ -> 24_000
    end
  end

  # Convert raw PCM (L16) to WAV format
  # L16 is 16-bit signed little-endian PCM, mono
  defp pcm_to_wav(pcm_data, sample_rate) do
    num_channels = 1
    bits_per_sample = 16
    byte_rate = sample_rate * num_channels * div(bits_per_sample, 8)
    block_align = num_channels * div(bits_per_sample, 8)
    data_size = byte_size(pcm_data)
    file_size = 36 + data_size

    # WAV header (44 bytes)
    header =
      <<"RIFF"::binary, file_size::little-32, "WAVE"::binary, "fmt "::binary, 16::little-32,
        1::little-16, num_channels::little-16, sample_rate::little-32, byte_rate::little-32,
        block_align::little-16, bits_per_sample::little-16, "data"::binary, data_size::little-32>>

    header <> pcm_data
  end

  defp get_api_key do
    Application.get_env(:langseed, :google_ai_api_key)
  end
end

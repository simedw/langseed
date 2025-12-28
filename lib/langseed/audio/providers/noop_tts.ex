defmodule Langseed.Audio.Providers.NoopTTS do
  @moduledoc """
  No-op TTS provider for when TTS is not configured.

  Always returns :not_configured for all operations.
  """

  @behaviour Langseed.Audio.TTSProvider

  @impl true
  def available?(), do: false

  @impl true
  def generate_audio(_text, _language, _voice_config) do
    {:error, :not_configured}
  end

  @impl true
  def voice_for_language(_language), do: nil
end

defmodule Langseed.Audio.TTSProvider do
  @moduledoc """
  Behavior for text-to-speech providers.

  Implementations should handle their own availability checks
  based on configuration/credentials.
  """

  @type language :: String.t()
  @type voice_config :: map()
  @type audio_data :: binary()
  @type mime_type :: String.t()

  @doc """
  Returns whether this TTS provider is available (configured and ready).
  """
  @callback available?() :: boolean()

  @doc """
  Generates audio for the given text.
  Returns the raw audio binary data and its MIME type.
  """
  @callback generate_audio(text :: String.t(), language, voice_config) ::
              {:ok, audio_data, mime_type} | {:error, term()}

  @doc """
  Returns the voice configuration for a given language.
  Returns nil if the language is not supported.
  """
  @callback voice_for_language(language) :: voice_config | nil
end

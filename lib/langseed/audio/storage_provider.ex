defmodule Langseed.Audio.StorageProvider do
  @moduledoc """
  Behavior for audio storage providers.

  Implementations should handle their own availability checks
  based on configuration/credentials.
  """

  @type path :: String.t()
  @type audio_data :: binary()
  @type signed_url :: String.t()
  @type content_type :: String.t()

  @doc """
  Returns whether this storage provider is available (configured and ready).
  """
  @callback available?() :: boolean()

  @doc """
  Stores audio data at the given path with the specified content type.
  Returns the path on success.
  """
  @callback store_audio(audio_data, path, content_type) :: {:ok, path} | {:error, term()}

  @doc """
  Checks if audio already exists at the given path.
  """
  @callback audio_exists?(path) :: boolean()

  @doc """
  Generates a pre-signed URL for accessing the audio.
  The URL should expire after the specified number of seconds.
  """
  @callback get_signed_url(path, expiry_seconds :: integer()) ::
              {:ok, signed_url} | {:error, term()}
end

defmodule Langseed.Audio.Providers.NoopStorage do
  @moduledoc """
  No-op storage provider for when storage is not configured.

  Always returns :not_configured for all operations.
  """

  @behaviour Langseed.Audio.StorageProvider

  @impl true
  def available?(), do: false

  @impl true
  def store_audio(_audio_data, _path, _content_type) do
    {:error, :not_configured}
  end

  @impl true
  def audio_exists?(_path), do: false

  @impl true
  def get_signed_url(_path, _expiry_seconds) do
    {:error, :not_configured}
  end
end

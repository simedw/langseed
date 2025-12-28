defmodule Langseed.Audio.Providers.R2Storage do
  @moduledoc """
  Cloudflare R2 storage provider for audio files.

  Uses ExAws.S3 with R2-compatible endpoint.
  Requires R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME.
  """

  @behaviour Langseed.Audio.StorageProvider

  @impl true
  def available?() do
    config = get_config()
    config[:access_key_id] != nil && config[:secret_access_key] != nil
  end

  @impl true
  def store_audio(audio_data, path, content_type) do
    opts = [
      content_type: content_type,
      acl: :private
    ]

    with {:ok, bucket} <- get_bucket_or_error(),
         {:ok, _} <-
           ExAws.S3.put_object(bucket, path, audio_data, opts)
           |> ExAws.request(exaws_config()) do
      {:ok, path}
    else
      {:error, :not_configured} ->
        {:error, :not_configured}

      {:error, reason} ->
        {:error, "R2 upload failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def audio_exists?(path) do
    # Simple boolean check - keep using if for two values
    case get_bucket_or_error() do
      {:error, _} ->
        false

      {:ok, bucket} ->
        case ExAws.S3.head_object(bucket, path)
             |> ExAws.request(exaws_config()) do
          {:ok, _} -> true
          {:error, _} -> false
        end
    end
  end

  @impl true
  def get_signed_url(path, expiry_seconds) do
    opts = [
      expires_in: expiry_seconds,
      virtual_host: false
    ]

    with {:ok, bucket} <- get_bucket_or_error() do
      ExAws.S3.presigned_url(exaws_config(), :get, bucket, path, opts)
    end
  end

  defp get_bucket_or_error do
    case get_config()[:bucket] do
      nil -> {:error, :not_configured}
      bucket -> {:ok, bucket}
    end
  end

  defp get_config do
    Application.get_env(:langseed, :r2_storage, %{})
  end

  defp exaws_config do
    config = get_config()

    %{
      access_key_id: config[:access_key_id],
      secret_access_key: config[:secret_access_key],
      region: "auto",
      host: "#{config[:account_id]}.r2.cloudflarestorage.com",
      scheme: "https://"
    }
  end
end

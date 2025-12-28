defmodule Langseed.Audio do
  @moduledoc """
  Audio generation and storage with pluggable providers.

  Supports three modes:
  1. No audio (TTS not configured)
  2. TTS-only (no storage, serves data URLs)
  3. TTS + Storage (optimal with R2 caching)

  Audio features are optional - the app works fully without any configuration.
  """

  alias Langseed.Utils.TextNormalizer

  require Logger

  @type audio_result :: {:ok, String.t() | nil} | {:error, term()}

  # Signed URL expiry: 24 hours (content-addressed, so long expiry is safe)
  @signed_url_expiry 86_400

  # Get providers from config, with defaults
  @spec tts_provider() :: module()
  defp tts_provider do
    Application.get_env(:langseed, :tts_provider, Langseed.Audio.Providers.GoogleTTS)
  end

  @spec storage_provider() :: module()
  defp storage_provider do
    Application.get_env(:langseed, :storage_provider, Langseed.Audio.Providers.R2Storage)
  end

  @doc """
  Returns whether TTS is available (configured and ready).
  """
  def tts_available?() do
    tts_provider().available?()
  end

  @doc """
  Returns whether storage is available (configured and ready).
  """
  def storage_available?() do
    storage_provider().available?()
  end

  @doc """
  Returns whether audio features are available.
  Only requires TTS at minimum (can work without storage).
  """
  @spec available?() :: boolean()
  def available?() do
    tts_available?()
  end

  @doc """
  Generates audio for a word/concept.
  """
  def generate_word_audio(concept) do
    generate_audio(concept.word, concept.language)
  end

  @doc """
  Generates audio for a sentence.
  """
  def generate_sentence_audio(sentence, language) do
    generate_audio(sentence, language)
  end

  @doc """
  Gets a fresh signed URL for a stored audio path (object key).
  Use this when you have a cached path and need a fresh signed URL.
  Returns {:ok, nil} if storage is not available.
  """
  @spec get_signed_url(String.t()) :: {:ok, String.t()} | {:ok, nil} | {:error, term()}
  def get_signed_url(path) when is_binary(path) do
    if storage_available?() do
      storage_provider().get_signed_url(path, @signed_url_expiry)
    else
      {:ok, nil}
    end
  end

  @doc """
  Computes the storage path for audio content (deterministic, content-addressed).
  Returns nil if the language is not supported for TTS.
  """
  @spec audio_path_for(String.t(), String.t()) :: String.t() | nil
  def audio_path_for(text, language) do
    case voice_config_for(language) do
      nil -> nil
      voice_config -> build_object_key(text, language, voice_config, "wav")
    end
  end

  @doc """
  Persists the audio path for a concept in the database.
  Only updates if the path has changed. Returns :ok on success or no-op.
  """
  @spec persist_audio_path(Langseed.Vocabulary.Concept.t(), String.t() | nil) :: :ok
  def persist_audio_path(_concept, nil), do: :ok

  def persist_audio_path(%{audio_path: current} = concept, path) when current != path do
    case Langseed.Vocabulary.update_concept(concept, %{audio_path: path}) do
      {:ok, _} ->
        Logger.debug("Cached audio_path for concept_id=#{concept.id}")
        :ok

      {:error, _changeset} ->
        Logger.error("Failed to cache audio_path for concept_id=#{concept.id}")
        :ok
    end
  end

  def persist_audio_path(_concept, _path), do: :ok

  # Private: Get voice config for language
  defp voice_config_for(language) do
    tts_provider().voice_for_language(language)
  end

  # Private: Build the R2 object key (centralized path building)
  defp build_object_key(text, language, voice_config, extension) do
    hash = TextNormalizer.generate_audio_hash(text, language, voice_config)
    voice_name = voice_config[:voice_name] || voice_config[:name] || "default"
    "tts/#{voice_name}/#{language}/#{hash}.#{extension}"
  end

  @doc """
  Generates audio for any text.

  When storage is available, caches the audio and returns a signed URL.
  When only TTS is available, returns a base64 data URL for direct embedding.
  Returns {:ok, nil} if TTS is not configured.
  """
  def generate_audio(text, language) do
    cond do
      tts_available?() && storage_available?() ->
        generate_and_cache(text, language)

      tts_available?() ->
        generate_direct(text, language)

      true ->
        {:ok, nil}
    end
  end

  # Private: Cache-first generation with storage
  @spec generate_and_cache(String.t(), String.t()) :: audio_result()
  defp generate_and_cache(text, language) do
    case voice_config_for(language) do
      nil -> {:ok, nil}
      voice_config -> do_generate_and_cache(text, language, voice_config)
    end
  end

  # Truly cache-first: check storage before generating TTS (saves API cost)
  defp do_generate_and_cache(text, language, voice_config) do
    # Use deterministic extension (.wav) since GoogleTTS always returns WAV
    path = build_object_key(text, language, voice_config, "wav")

    # Check cache first - avoid TTS call if already stored
    if storage_provider().audio_exists?(path) do
      Logger.debug("Cache hit for audio")
      storage_provider().get_signed_url(path, @signed_url_expiry)
    else
      # Cache miss - generate and store
      generate_and_store(text, language, voice_config, path)
    end
  end

  defp generate_and_store(text, language, voice_config, path) do
    case tts_provider().generate_audio(text, language, voice_config) do
      {:ok, audio_data, mime_type} ->
        with {:ok, ^path} <- storage_provider().store_audio(audio_data, path, mime_type),
             {:ok, url} <- storage_provider().get_signed_url(path, @signed_url_expiry) do
          {:ok, url}
        else
          {:error, reason} ->
            Logger.warning("Audio storage failed")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning("Audio generation failed")
        {:error, reason}
    end
  end

  # Private: Direct generation without storage (returns data URL)
  @spec generate_direct(String.t(), String.t()) :: audio_result()
  defp generate_direct(text, language) do
    voice_config = tts_provider().voice_for_language(language)

    if voice_config == nil do
      {:ok, nil}
    else
      case tts_provider().generate_audio(text, language, voice_config) do
        {:ok, audio_data, mime_type} ->
          # Return as base64 data URL for direct embedding
          # Note: ~300KB per sentence, no caching across users
          data_url = "data:#{mime_type};base64,#{Base.encode64(audio_data)}"
          {:ok, data_url}

        {:error, reason} ->
          Logger.warning("Audio generation failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end

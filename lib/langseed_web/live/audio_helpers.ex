defmodule LangseedWeb.AudioHelpers do
  @moduledoc """
  Shared audio generation helpers for LiveViews.

  Add `use LangseedWeb.AudioHelpers` to your LiveView to automatically
  handle speak button audio generation.
  """

  defmacro __using__(_opts) do
    quote do
      @impl true
      def handle_info({:generate_speak_audio, component_id, text, concept_id, language}, socket) do
        LangseedWeb.AudioHelpers.handle_generate_speak_audio(
          socket,
          component_id,
          text,
          concept_id,
          language
        )
      end

      @impl true
      def handle_info({:speak_audio_result, component_id, result}, socket) do
        LangseedWeb.AudioHelpers.handle_speak_audio_result(socket, component_id, result)
      end
    end
  end

  alias Langseed.Audio
  alias Langseed.Vocabulary.Concept

  require Logger

  @type audio_result :: {:ok, String.t()} | {:ok, nil} | {:error, term()}

  @doc """
  Handles the audio generation request from SpeakButtonComponent.
  """
  @spec handle_generate_speak_audio(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          String.t(),
          integer() | nil,
          String.t()
        ) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_generate_speak_audio(socket, component_id, text, concept_id, language) do
    parent_pid = self()

    Task.Supervisor.start_child(Langseed.TaskSupervisor, fn ->
      generate_and_notify(parent_pid, component_id, text, concept_id, language)
    end)

    {:noreply, socket}
  end

  @spec generate_and_notify(pid(), String.t(), String.t(), integer() | nil, String.t()) :: :ok
  defp generate_and_notify(parent_pid, component_id, text, concept_id, language) do
    Logger.debug("Generating audio for concept_id=#{inspect(concept_id)}")

    result =
      case Audio.generate_audio(text, language) do
        {:ok, url} when not is_nil(url) ->
          Logger.debug("Audio generated successfully")
          # Cache the object key (path), not the signed URL
          maybe_cache_audio_path(text, language, concept_id)
          {:ok, url}

        {:ok, nil} ->
          Logger.debug("No TTS for language=#{language}, using browser TTS")
          {:ok, nil}

        {:error, _reason} = error ->
          Logger.warning("Audio generation failed for concept_id=#{inspect(concept_id)}")
          error
      end

    send(parent_pid, {:speak_audio_result, component_id, result})
  end

  # Cache the R2 object key (path) in the database, NOT the signed URL.
  # Signed URLs expire; paths are permanent and can be signed on-demand.
  @spec maybe_cache_audio_path(String.t(), String.t(), integer() | nil) :: :ok
  defp maybe_cache_audio_path(_text, _language, nil), do: :ok

  defp maybe_cache_audio_path(text, language, concept_id) do
    path = Audio.audio_path_for(text, language)

    case Langseed.Repo.get(Concept, concept_id) do
      nil ->
        Logger.warning("Cannot cache audio_path: concept #{concept_id} not found")

      concept ->
        Audio.persist_audio_path(concept, path)
    end
  end

  @doc """
  Handles the audio generation result and updates the component.
  """
  def handle_speak_audio_result(socket, component_id, result) do
    case result do
      {:ok, url} when not is_nil(url) ->
        Phoenix.LiveView.send_update(
          LangseedWeb.SpeakButtonComponent,
          id: component_id,
          audio_url: url,
          loading: false,
          __play__: true
        )

      _ ->
        Phoenix.LiveView.send_update(
          LangseedWeb.SpeakButtonComponent,
          id: component_id,
          loading: false,
          __fallback__: true
        )
    end

    {:noreply, socket}
  end
end

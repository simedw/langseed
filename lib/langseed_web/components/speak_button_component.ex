defmodule LangseedWeb.SpeakButtonComponent do
  @moduledoc """
  A self-contained speak button LiveComponent that handles audio generation.

  Uses Gemini TTS for on-demand audio generation with loading states.
  Falls back to browser TTS if no concept_id is provided.
  """

  use LangseedWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <button
      type="button"
      phx-hook="AudioPlayer"
      id={@id}
      phx-target={@myself}
      phx-click="speak"
      data-text={@text}
      data-audio-url={@audio_url}
      data-language={@language}
      class="btn btn-ghost btn-circle btn-sm speak-btn"
      title={audio_title(@audio_url)}
    >
      <%= if @loading do %>
        <span class="loading loading-spinner loading-sm"></span>
      <% else %>
        <.icon name={audio_icon(@audio_url)} class="size-5" />
      <% end %>
    </button>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Prefer non-nil audio_url: use parent's if provided, else keep component's own
    # This prevents parent re-renders from overwriting a generated URL with nil
    parent_audio_url = assigns[:audio_url]
    current_audio_url = socket.assigns[:audio_url]
    audio_url = non_empty_url(parent_audio_url) || non_empty_url(current_audio_url)

    socket =
      socket
      |> assign(Map.drop(assigns, [:__play__, :__fallback__, :audio_url]))
      |> assign_new(:loading, fn -> false end)
      |> assign(:audio_url, audio_url)
      |> assign_new(:language, fn -> assigns[:language] || "zh" end)

    # Handle special update signals (include id to filter on client)
    socket =
      cond do
        assigns[:__play__] && assigns[:audio_url] ->
          push_event(socket, "speak-audio-play", %{
            id: socket.assigns.id,
            url: assigns.audio_url
          })

        assigns[:__fallback__] ->
          push_event(socket, "speak-browser-tts", %{
            id: socket.assigns.id,
            text: socket.assigns.text,
            language: socket.assigns.language
          })

        true ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("speak", _, socket) do
    audio_url = socket.assigns[:audio_url]
    concept_id = socket.assigns[:concept_id]
    id = socket.assigns.id
    text = socket.assigns.text
    language = socket.assigns.language

    cond do
      # Already have audio URL - just play it
      audio_url && audio_url != "" ->
        {:noreply, push_event(socket, "speak-audio-play", %{id: id, url: audio_url})}

      # Have concept_id - generate on-demand
      concept_id ->
        send(self(), {:generate_speak_audio, id, text, concept_id, language})
        {:noreply, assign(socket, loading: true)}

      # No concept_id - let JS hook handle browser TTS
      true ->
        {:noreply,
         push_event(socket, "speak-browser-tts", %{id: id, text: text, language: language})}
    end
  end

  @impl true
  def handle_event("audio_ready", %{"url" => url}, socket) do
    socket =
      socket
      |> assign(loading: false, audio_url: url)
      |> push_event("speak-audio-play", %{id: socket.assigns.id, url: url})

    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_failed", _, socket) do
    # Fall back to browser TTS
    socket =
      socket
      |> assign(loading: false)
      |> push_event("speak-browser-tts", %{
        id: socket.assigns.id,
        text: socket.assigns.text,
        language: socket.assigns.language
      })

    {:noreply, socket}
  end

  # Returns URL if non-empty, nil otherwise
  defp non_empty_url(nil), do: nil
  defp non_empty_url(""), do: nil
  defp non_empty_url(url), do: url

  # Solid icon when audio is ready, outline when needs generation
  defp audio_icon(nil), do: "hero-speaker-wave"
  defp audio_icon(""), do: "hero-speaker-wave"
  defp audio_icon(_url), do: "hero-speaker-wave-solid"

  defp audio_title(nil), do: gettext("Generate & play pronunciation")
  defp audio_title(""), do: gettext("Generate & play pronunciation")
  defp audio_title(_url), do: gettext("Play pronunciation")
end

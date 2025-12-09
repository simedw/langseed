defmodule LangseedWeb.VocabularyLive do
  use LangseedWeb, :live_view

  alias Langseed.Vocabulary
  alias Langseed.Services.WordImporter
  alias Langseed.HSK

  @impl true
  def mount(_params, _session, socket) do
    scope = current_scope(socket)
    concepts = Vocabulary.list_concepts(scope)
    known_words = Vocabulary.known_words(scope)

    {:ok,
     assign(socket,
       page_title: gettext("Vocabulary"),
       concepts: concepts,
       concept_count: length(concepts),
       known_words: known_words,
       expanded_id: nil,
       expanded_concept: nil,
       importing_words: []
     )}
  end

  @impl true
  def handle_event("expand", %{"id" => id}, socket) do
    scope = current_scope(socket)
    concept = Vocabulary.get_concept!(scope, id)
    {:noreply, assign(socket, expanded_id: id, expanded_concept: concept)}
  end

  @impl true
  def handle_event("collapse", _, socket) do
    {:noreply, assign(socket, expanded_id: nil, expanded_concept: nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = current_scope(socket)
    concept = Vocabulary.get_concept!(scope, id)
    {:ok, _} = Vocabulary.delete_concept(concept)

    concepts = Vocabulary.list_concepts(scope)
    known_words = Vocabulary.known_words(scope)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{concept.word}")
     |> assign(
       concepts: concepts,
       concept_count: length(concepts),
       known_words: known_words,
       expanded_id: nil,
       expanded_concept: nil
     )}
  end

  @impl true
  def handle_event("update_understanding", %{"id" => id, "value" => value}, socket) do
    scope = current_scope(socket)
    concept = Vocabulary.get_concept!(scope, id)
    level = String.to_integer(value)
    {:ok, updated_concept} = Vocabulary.update_understanding(concept, level)

    concepts = Vocabulary.list_concepts(scope)

    {:noreply, assign(socket, concepts: concepts, expanded_concept: updated_concept)}
  end

  @impl true
  def handle_event("add_desired_word", %{"word" => word, "context" => context}, socket) do
    scope = current_scope(socket)

    # Check if word already exists
    if Vocabulary.word_known?(scope, word) do
      {:noreply, put_flash(socket, :info, "#{word} is already in your vocabulary")}
    else
      # Import the word asynchronously
      {:noreply,
       socket
       |> assign(importing_words: [word | socket.assigns.importing_words])
       |> start_async({:import_word, word}, fn ->
         WordImporter.import_words(scope, [word], context)
       end)}
    end
  end

  @impl true
  def handle_event("toggle_pause", %{"id" => id}, socket) do
    scope = current_scope(socket)
    concept = Vocabulary.get_concept!(scope, id)
    {:ok, updated_concept} = Vocabulary.toggle_paused(concept)

    concepts = Vocabulary.list_concepts(scope)
    action = if updated_concept.paused, do: "Paused", else: "Resumed"

    {:noreply,
     socket
     |> put_flash(:info, "#{action} #{concept.word}")
     |> assign(concepts: concepts, expanded_concept: updated_concept)}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[_], []}}, socket) do
    scope = current_scope(socket)
    concepts = Vocabulary.list_concepts(scope)
    known_words = Vocabulary.known_words(scope)

    # Refresh the expanded concept if it's still open (to update desired_words display)
    expanded_concept =
      if socket.assigns.expanded_id do
        Vocabulary.get_concept!(scope, socket.assigns.expanded_id)
      else
        nil
      end

    {:noreply,
     socket
     |> put_flash(:success, "Added #{word}")
     |> assign(
       concepts: concepts,
       concept_count: length(concepts),
       known_words: known_words,
       expanded_concept: expanded_concept,
       importing_words: List.delete(socket.assigns.importing_words, word)
     )}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[], [_]}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("Failed to add %{word}", word: word))
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def handle_async({:import_word, word}, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("Failed to add %{word}", word: word))
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-2xl font-bold">{gettext("Vocabulary")}</h1>
          <span class="badge badge-lg">{@concept_count}</span>
        </div>

        <div class="flex flex-wrap gap-2">
          <%= for concept <- @concepts do %>
            <.concept_chip concept={concept} />
          <% end %>
        </div>

        <%= if @concept_count == 0 do %>
          <div class="text-center py-12">
            <p class="text-lg opacity-70">{gettext("No vocabulary yet")}</p>
            <p class="text-sm opacity-50 mt-2">
              {gettext("Go to %{link} to add words", link: ~s(<a href="/analyze" class="link link-primary">#{gettext("Analyze")}</a>)) |> Phoenix.HTML.raw()}
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @expanded_id do %>
      <div
        class="fixed inset-0 bg-black/50 z-40"
        phx-click="collapse"
      />
      <.concept_card
        concept={@expanded_concept}
        show_desired_words={true}
        show_example_sentence={true}
        show_understanding_slider={true}
        show_delete_button={true}
        show_pause_button={true}
        importing_words={@importing_words}
        known_words={@known_words}
      />
    <% end %>
    """
  end

  defp concept_chip(assigns) do
    # HSK level only for Chinese
    hsk_level = if assigns.concept.language == "zh", do: HSK.lookup(assigns.concept.word), else: nil
    assigns = assign(assigns, :hsk_level, hsk_level)

    ~H"""
    <button
      class={[
        "px-3 py-2 rounded-lg text-2xl font-bold transition-all hover:scale-105 cursor-pointer relative",
        @concept.paused && "opacity-50"
      ]}
      style={"background-color: #{understanding_color(@concept.understanding)}20; border: 2px solid #{understanding_color(@concept.understanding)}"}
      phx-click="expand"
      phx-value-id={@concept.id}
    >
      {@concept.word}
      <%= if @hsk_level do %>
        <span class="absolute -top-1 -left-1 text-[10px] bg-base-300 px-1 rounded opacity-70">
          {@hsk_level}
        </span>
      <% end %>
      <%= if @concept.paused do %>
        <span class="absolute -top-1 -right-1 text-xs">⏸️</span>
      <% end %>
    </button>
    """
  end
end

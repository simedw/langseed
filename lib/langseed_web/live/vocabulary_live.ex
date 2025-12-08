defmodule LangseedWeb.VocabularyLive do
  use LangseedWeb, :live_view

  alias Langseed.Vocabulary
  alias Langseed.Services.WordImporter

  @impl true
  def mount(_params, _session, socket) do
    user = current_user(socket)
    concepts = Vocabulary.list_concepts(user)

    {:ok,
     assign(socket,
       page_title: "词汇",
       concepts: concepts,
       concept_count: length(concepts),
       expanded_id: nil,
       expanded_concept: nil,
       importing_words: []
     )}
  end

  @impl true
  def handle_event("expand", %{"id" => id}, socket) do
    user = current_user(socket)
    concept = Vocabulary.get_concept!(user, id)
    {:noreply, assign(socket, expanded_id: id, expanded_concept: concept)}
  end

  @impl true
  def handle_event("collapse", _, socket) do
    {:noreply, assign(socket, expanded_id: nil, expanded_concept: nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = current_user(socket)
    concept = Vocabulary.get_concept!(user, id)
    {:ok, _} = Vocabulary.delete_concept(concept)

    concepts = Vocabulary.list_concepts(user)

    {:noreply,
     socket
     |> put_flash(:info, "删除了 #{concept.word}")
     |> assign(
       concepts: concepts,
       concept_count: length(concepts),
       expanded_id: nil,
       expanded_concept: nil
     )}
  end

  @impl true
  def handle_event("update_understanding", %{"id" => id, "value" => value}, socket) do
    user = current_user(socket)
    concept = Vocabulary.get_concept!(user, id)
    level = String.to_integer(value)
    {:ok, updated_concept} = Vocabulary.update_understanding(concept, level)

    concepts = Vocabulary.list_concepts(user)

    {:noreply, assign(socket, concepts: concepts, expanded_concept: updated_concept)}
  end

  @impl true
  def handle_event("add_desired_word", %{"word" => word, "context" => context}, socket) do
    user = current_user(socket)

    # Check if word already exists
    if Vocabulary.word_known?(user, word) do
      {:noreply, put_flash(socket, :info, "#{word} 已经在你的词汇表里了")}
    else
      # Import the word asynchronously
      {:noreply,
       socket
       |> assign(importing_words: [word | socket.assigns.importing_words])
       |> start_async({:import_word, word}, fn ->
         WordImporter.import_words(user, [word], context)
       end)}
    end
  end

  @impl true
  def handle_event("toggle_pause", %{"id" => id}, socket) do
    user = current_user(socket)
    concept = Vocabulary.get_concept!(user, id)
    {:ok, updated_concept} = Vocabulary.toggle_paused(concept)

    concepts = Vocabulary.list_concepts(user)
    action = if updated_concept.paused, do: "暂停了", else: "恢复了"

    {:noreply,
     socket
     |> put_flash(:info, "#{action} #{concept.word}")
     |> assign(concepts: concepts, expanded_concept: updated_concept)}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[_], []}}, socket) do
    user = current_user(socket)
    concepts = Vocabulary.list_concepts(user)

    # Refresh the expanded concept if it's still open (to update desired_words display)
    expanded_concept =
      if socket.assigns.expanded_id do
        Vocabulary.get_concept!(user, socket.assigns.expanded_id)
      else
        nil
      end

    {:noreply,
     socket
     |> put_flash(:success, "添加了 #{word} ✓")
     |> assign(
       concepts: concepts,
       concept_count: length(concepts),
       expanded_concept: expanded_concept,
       importing_words: List.delete(socket.assigns.importing_words, word)
     )}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[], [_]}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "添加 #{word} 失败")
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def handle_async({:import_word, word}, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "添加 #{word} 失败")
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-2xl font-bold">词汇</h1>
          <span class="badge badge-lg">{@concept_count}</span>
        </div>

        <div class="flex flex-wrap gap-2">
          <%= for concept <- @concepts do %>
            <.concept_chip concept={concept} />
          <% end %>
        </div>

        <%= if @concept_count == 0 do %>
          <div class="text-center py-12">
            <p class="text-lg opacity-70">还没有词汇</p>
            <p class="text-sm opacity-50 mt-2">
              去 <a href="/analyze" class="link link-primary">分析</a> 添加
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
      />
    <% end %>
    """
  end

  defp concept_chip(assigns) do
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
      <%= if @concept.paused do %>
        <span class="absolute -top-1 -right-1 text-xs">⏸️</span>
      <% end %>
    </button>
    """
  end
end

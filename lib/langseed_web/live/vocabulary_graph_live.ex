defmodule LangseedWeb.VocabularyGraphLive do
  use LangseedWeb, :live_view
  use LangseedWeb.AudioHelpers
  use LangseedWeb.WordImportHelpers

  alias Langseed.Vocabulary
  alias Langseed.Vocabulary.Graph

  @impl true
  def mount(_params, _session, socket) do
    scope = current_scope(socket)
    graph = Graph.build_graph(scope)
    stats = Graph.graph_stats(scope)
    known_words = Vocabulary.known_words(scope)

    {:ok,
     assign(socket,
       page_title: gettext("Graph"),
       graph_data: Jason.encode!(graph),
       stats: stats,
       known_words: known_words,
       selected_concept: nil
     )}
  end

  @impl true
  def handle_event("select_word", %{"word" => word}, socket) do
    scope = current_scope(socket)
    concept = Vocabulary.get_concept_by_word(scope, word)
    {:noreply, assign(socket, selected_concept: concept)}
  end

  @impl true
  def handle_event("collapse", _, socket) do
    {:noreply, assign(socket, selected_concept: nil)}
  end

  @impl true
  def handle_event("toggle_pause", %{"id" => id}, socket) do
    scope = current_scope(socket)
    concept = Vocabulary.get_concept!(scope, id)
    {:ok, updated_concept} = Vocabulary.toggle_paused(concept)

    flash_message =
      if updated_concept.paused,
        do: gettext("Paused %{word}", word: concept.word),
        else: gettext("Resumed %{word}", word: concept.word)

    {:noreply,
     socket
     |> put_flash(:info, flash_message)
     |> assign(selected_concept: updated_concept)}
  end

  # Handle practice_ready check (scheduled by user_auth on mount)
  @impl true
  def handle_info(:check_practice_ready, socket) do
    Process.send_after(self(), :check_practice_ready, 30_000)
    scope = current_scope(socket)
    practice_ready = Langseed.Practice.has_practice_ready?(scope)
    {:noreply, assign(socket, :practice_ready, practice_ready)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-2xl font-bold">{gettext("Vocabulary Graph")}</h1>
          <a href="/vocabulary" class="btn btn-sm btn-ghost">
            <.icon name="hero-list-bullet" class="size-4" /> {gettext("List view")}
          </a>
        </div>

        <div class="stats stats-vertical lg:stats-horizontal shadow mb-4 w-full">
          <div class="stat">
            <div class="stat-title">{gettext("Words")}</div>
            <div class="stat-value text-primary">{@stats.node_count}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("Connections")}</div>
            <div class="stat-value text-secondary">{@stats.edge_count}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("Isolated")}</div>
            <div class="stat-value text-warning">{@stats.isolated_count}</div>
            <div class="stat-desc">{gettext("Words without connections")}</div>
          </div>
        </div>

        <div class="grid lg:grid-cols-2 gap-4 mb-4">
          <.stats_card
            title={gettext("Foundational words")}
            subtitle={gettext("Used to explain most other words")}
            items={@stats.foundational}
          />
          <.stats_card
            title={gettext("Complex words")}
            subtitle={gettext("Need most words to explain")}
            items={@stats.complex}
          />
        </div>

        <div
          id="word-graph"
          phx-hook="WordGraph"
          phx-update="ignore"
          data-graph={@graph_data}
          data-empty-message={gettext("No vocabulary data yet")}
          class="card bg-base-200 shadow-lg overflow-hidden"
          style="height: 500px;"
        >
          <div class="flex items-center justify-center h-full">
            <span class="loading loading-spinner loading-lg"></span>
          </div>
        </div>

        <div class="mt-4 text-sm opacity-60">
          <p>
            💡 {gettext(
              "Click nodes to see details. Drag to adjust position. Color shows understanding level (red → yellow → green)."
            )}
          </p>
          <p>{gettext("Arrow direction: A → B means A is used to explain B.")}</p>
        </div>
      </div>
    </div>

    <%= if @selected_concept do %>
      <div
        class="fixed inset-0 bg-black/50 z-40"
        phx-click="collapse"
      />
      <.concept_card
        concept={@selected_concept}
        show_desired_words={true}
        show_example_sentence={true}
        show_pause_button={true}
        known_words={@known_words}
      />
    <% end %>
    """
  end

  defp stats_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow">
      <div class="card-body p-4">
        <h3 class="card-title text-sm">{@title}</h3>
        <p class="text-xs opacity-60">{@subtitle}</p>
        <div class="flex flex-wrap gap-1 mt-2">
          <%= for {word, count} <- @items do %>
            <span class="badge badge-ghost">
              {word} <span class="ml-1 opacity-60">({count})</span>
            </span>
          <% end %>
          <%= if Enum.empty?(@items) do %>
            <span class="text-xs opacity-40">{gettext("No data")}</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

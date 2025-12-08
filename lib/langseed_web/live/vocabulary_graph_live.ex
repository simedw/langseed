defmodule LangseedWeb.VocabularyGraphLive do
  use LangseedWeb, :live_view

  alias Langseed.Vocabulary
  alias Langseed.Vocabulary.Graph

  @impl true
  def mount(_params, _session, socket) do
    user = current_user(socket)
    graph = Graph.build_graph(user)
    stats = Graph.graph_stats(user)

    {:ok,
     assign(socket,
       page_title: "词汇图谱",
       graph_data: Jason.encode!(graph),
       stats: stats,
       selected_concept: nil
     )}
  end

  @impl true
  def handle_event("select_word", %{"word" => word}, socket) do
    user = current_user(socket)
    concept = Vocabulary.get_concept_by_word(user, word)
    {:noreply, assign(socket, selected_concept: concept)}
  end

  @impl true
  def handle_event("collapse", _, socket) do
    {:noreply, assign(socket, selected_concept: nil)}
  end

  @impl true
  def handle_event("toggle_pause", %{"id" => id}, socket) do
    user = current_user(socket)
    concept = Vocabulary.get_concept!(user, id)
    {:ok, updated_concept} = Vocabulary.toggle_paused(concept)

    action = if updated_concept.paused, do: "暂停了", else: "恢复了"

    {:noreply,
     socket
     |> put_flash(:info, "#{action} #{concept.word}")
     |> assign(selected_concept: updated_concept)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-2xl font-bold">词汇图谱</h1>
          <a href="/" class="btn btn-sm btn-ghost">
            <.icon name="hero-list-bullet" class="size-4" /> 列表视图
          </a>
        </div>

        <div class="stats stats-vertical lg:stats-horizontal shadow mb-4 w-full">
          <div class="stat">
            <div class="stat-title">词汇</div>
            <div class="stat-value text-primary">{@stats.node_count}</div>
          </div>
          <div class="stat">
            <div class="stat-title">关联</div>
            <div class="stat-value text-secondary">{@stats.edge_count}</div>
          </div>
          <div class="stat">
            <div class="stat-title">孤立词</div>
            <div class="stat-value text-warning">{@stats.isolated_count}</div>
            <div class="stat-desc">没有关联的词</div>
          </div>
        </div>

        <div class="grid lg:grid-cols-2 gap-4 mb-4">
          <.stats_card
            title="基础词汇"
            subtitle="用来解释最多其他词"
            items={@stats.foundational}
          />
          <.stats_card
            title="复杂词汇"
            subtitle="需要最多词来解释"
            items={@stats.complex}
          />
        </div>

        <div
          id="word-graph"
          phx-hook="WordGraph"
          phx-update="ignore"
          data-graph={@graph_data}
          class="card bg-base-200 shadow-lg overflow-hidden"
          style="height: 500px;"
        >
          <div class="flex items-center justify-center h-full">
            <span class="loading loading-spinner loading-lg"></span>
          </div>
        </div>

        <div class="mt-4 text-sm opacity-60">
          <p>💡 点击节点查看详情。拖动可调整位置。颜色表示理解程度（红→黄→绿）。</p>
          <p>箭头方向：A → B 表示 A 被用来解释 B。</p>
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
            <span class="text-xs opacity-40">暂无数据</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

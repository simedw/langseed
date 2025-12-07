defmodule LangseedWeb.VocabularyLive do
  use LangseedWeb, :live_view

  alias Langseed.Vocabulary

  @impl true
  def mount(_params, _session, socket) do
    concepts = Vocabulary.list_concepts()

    {:ok,
     assign(socket,
       page_title: "词汇",
       concepts: concepts,
       concept_count: length(concepts),
       expanded_id: nil,
       expanded_concept: nil
     )}
  end

  @impl true
  def handle_event("expand", %{"id" => id}, socket) do
    concept = Vocabulary.get_concept!(id)
    {:noreply, assign(socket, expanded_id: id, expanded_concept: concept)}
  end

  @impl true
  def handle_event("collapse", _, socket) do
    {:noreply, assign(socket, expanded_id: nil, expanded_concept: nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    concept = Vocabulary.get_concept!(id)
    {:ok, _} = Vocabulary.delete_concept(concept)

    concepts = Vocabulary.list_concepts()

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
    concept = Vocabulary.get_concept!(id)
    level = String.to_integer(value)
    {:ok, updated_concept} = Vocabulary.update_understanding(concept, level)

    concepts = Vocabulary.list_concepts()

    {:noreply, assign(socket, concepts: concepts, expanded_concept: updated_concept)}
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
      <.expanded_card concept={@expanded_concept} />
    <% end %>
    """
  end

  defp concept_chip(assigns) do
    ~H"""
    <button
      class="px-3 py-2 rounded-lg text-2xl font-bold transition-all hover:scale-105 cursor-pointer"
      style={"background-color: #{understanding_color(@concept.understanding)}20; border: 2px solid #{understanding_color(@concept.understanding)}"}
      phx-click="expand"
      phx-value-id={@concept.id}
    >
      {@concept.word}
    </button>
    """
  end

  defp expanded_card(assigns) do
    ~H"""
    <div class="fixed inset-x-4 top-1/2 -translate-y-1/2 z-50 max-w-md mx-auto">
      <div
        class="card bg-base-100 shadow-2xl"
        style={"border-left: 6px solid #{understanding_color(@concept.understanding)}"}
      >
        <div class="card-body p-5">
          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-2">
                <span class="text-4xl font-bold">{@concept.word}</span>
                <.speak_button text={@concept.word} />
              </div>
              <p class="text-xl text-primary mt-1">{@concept.pinyin}</p>
              <span class="badge badge-sm badge-ghost">{@concept.part_of_speech}</span>
            </div>
            <button
              class="btn btn-ghost btn-sm btn-circle"
              phx-click="collapse"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <%= if @concept.explanations && length(@concept.explanations) > 0 do %>
            <div class="mt-4 p-3 bg-base-200 rounded-lg space-y-2">
              <%= for explanation <- @concept.explanations do %>
                <p class="text-lg">{explanation}</p>
              <% end %>
              <%= if @concept.explanation_quality do %>
                <div class="flex items-center gap-1 mt-2 text-sm opacity-60">
                  <span>解释质量:</span>
                  <.quality_stars quality={@concept.explanation_quality} />
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @concept.desired_words && length(@concept.desired_words) > 0 do %>
            <div class="mt-3 p-3 bg-info/10 rounded-lg">
              <p class="text-xs opacity-60 mb-2">💡 学这些词可以改进解释:</p>
              <div class="flex flex-wrap gap-1">
                <%= for word <- @concept.desired_words do %>
                  <span class="badge badge-sm badge-info badge-outline">{word}</span>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @concept.example_sentence do %>
            <p class="text-sm italic opacity-70 mt-2 border-l-2 border-base-300 pl-2">
              {@concept.example_sentence}
            </p>
          <% end %>

          <div class="mt-4">
            <div class="flex items-center gap-2">
              <span class="text-sm opacity-50">理解</span>
              <input
                type="range"
                min="0"
                max="100"
                value={@concept.understanding}
                class="range range-sm flex-1"
                style={"accent-color: #{understanding_color(@concept.understanding)}"}
                phx-change="update_understanding"
                phx-value-id={@concept.id}
                name="value"
              />
              <span class="text-sm font-mono w-10">{@concept.understanding}%</span>
            </div>
          </div>

          <details class="mt-3">
            <summary class="text-xs opacity-40 cursor-pointer hover:opacity-60">
              👁️ 英文
            </summary>
            <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
          </details>

          <div class="card-actions justify-end mt-4">
            <button
              class="btn btn-error btn-sm"
              phx-click="delete"
              phx-value-id={@concept.id}
              data-confirm={"删除 #{@concept.word}?"}
            >
              <.icon name="hero-trash" class="size-4" /> 删除
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp quality_stars(assigns) do
    ~H"""
    <span class="inline-flex">
      <%= for i <- 1..5 do %>
        <%= if i <= @quality do %>
          <span class="text-warning">★</span>
        <% else %>
          <span class="opacity-30">☆</span>
        <% end %>
      <% end %>
    </span>
    """
  end

  defp understanding_color(level) do
    # Gradient from red (0) -> yellow (50) -> green (100)
    cond do
      level < 50 ->
        # Red to yellow
        ratio = level / 50
        r = 239
        g = round(68 + (171 - 68) * ratio)
        b = round(68 + (8 - 68) * ratio)
        "rgb(#{r}, #{g}, #{b})"

      true ->
        # Yellow to green
        ratio = (level - 50) / 50
        r = round(234 - (234 - 34) * ratio)
        g = round(179 + (197 - 179) * ratio)
        b = round(8 + (94 - 8) * ratio)
        "rgb(#{r}, #{g}, #{b})"
    end
  end

  defp speak_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-hook="Speak"
      id={"speak-#{:erlang.phash2(@text)}"}
      data-text={@text}
      class="btn btn-ghost btn-circle btn-sm"
      title="播放发音"
    >
      <.icon name="hero-speaker-wave" class="size-5" />
    </button>
    """
  end
end

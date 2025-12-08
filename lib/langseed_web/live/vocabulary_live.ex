defmodule LangseedWeb.VocabularyLive do
  use LangseedWeb, :live_view

  alias Langseed.Vocabulary

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
       expanded_concept: nil
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
      />
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
end

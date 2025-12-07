defmodule LangseedWeb.TextsLive do
  use LangseedWeb, :live_view

  alias Langseed.Library

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Texts",
       texts: Library.list_texts(),
       editing_id: nil,
       edit_title: ""
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    text = Library.get_text!(id)
    {:ok, _} = Library.delete_text(text)

    {:noreply,
     socket
     |> assign(texts: Library.list_texts())
     |> put_flash(:info, "已删除")}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    text = Library.get_text!(id)
    {:noreply, assign(socket, editing_id: String.to_integer(id), edit_title: text.title)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_id: nil, edit_title: "")}
  end

  @impl true
  def handle_event("update_edit_title", %{"value" => value}, socket) do
    {:noreply, assign(socket, edit_title: value)}
  end

  @impl true
  def handle_event("save_title", %{"id" => id}, socket) do
    text = Library.get_text!(id)
    {:ok, _} = Library.update_text(text, %{title: socket.assigns.edit_title})

    {:noreply,
     socket
     |> assign(texts: Library.list_texts(), editing_id: nil, edit_title: "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="p-4">
        <h1 class="text-2xl font-bold mb-4">文本</h1>

        <%= if length(@texts) == 0 do %>
          <div class="text-center py-12">
            <p class="text-lg opacity-70">还没有保存的文本</p>
            <p class="text-sm opacity-50 mt-2">
              去 <a href="/analyze" class="link link-primary">分析</a> 页面保存文本
            </p>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for text <- @texts do %>
              <.text_card
                text={text}
                editing={@editing_id == text.id}
                edit_title={@edit_title}
              />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp text_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-sm">
      <div class="card-body p-4">
        <div class="flex items-start justify-between gap-2">
          <div class="flex-1 min-w-0">
            <%= if @editing do %>
              <form phx-submit="save_title" phx-value-id={@text.id} class="flex gap-2">
                <input
                  type="text"
                  class="input input-sm input-bordered flex-1"
                  value={@edit_title}
                  phx-change="update_edit_title"
                  phx-debounce="100"
                  name="value"
                  autofocus
                />
                <button type="submit" class="btn btn-sm btn-success">
                  <.icon name="hero-check" class="size-4" />
                </button>
                <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_edit">
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </form>
            <% else %>
              <h3 class="font-semibold text-lg truncate">{@text.title}</h3>
            <% end %>

            <p class="text-sm opacity-60 mt-1 line-clamp-2">
              {String.slice(@text.content, 0, 100)}{if String.length(@text.content) > 100, do: "..."}
            </p>

            <p class="text-xs opacity-40 mt-2">
              {Calendar.strftime(@text.updated_at, "%Y-%m-%d %H:%M")}
            </p>
          </div>

          <div class="flex gap-1">
            <a
              href={"/analyze?text_id=#{@text.id}"}
              class="btn btn-sm btn-primary"
            >
              <.icon name="hero-book-open" class="size-4" /> 读
            </a>
            <%= unless @editing do %>
              <button
                class="btn btn-sm btn-ghost"
                phx-click="start_edit"
                phx-value-id={@text.id}
              >
                <.icon name="hero-pencil" class="size-4" />
              </button>
            <% end %>
            <button
              class="btn btn-sm btn-ghost text-error"
              phx-click="delete"
              phx-value-id={@text.id}
              data-confirm="删除这个文本?"
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

defmodule LangseedWeb.TextAnalysisLive do
  use LangseedWeb, :live_view

  import LangseedWeb.TextAnalysisComponents

  alias Langseed.Vocabulary
  alias Langseed.Library
  alias Langseed.Language
  alias Langseed.Services.WordImporter

  @impl true
  def mount(_params, _session, socket) do
    user = current_user(socket)

    {:ok,
     assign(socket,
       page_title: "Analyze",
       input_text: "",
       segments: [],
       selected_words: MapSet.new(),
       known_words: Vocabulary.known_words_with_understanding(user),
       analyzing: false,
       importing_words: [],
       expanded_concept: nil,
       current_text_id: nil,
       recent_texts: Library.list_recent_texts(user, 5),
       show_load_menu: false,
       show_hsk: false
     )}
  end

  @impl true
  def handle_params(%{"text_id" => text_id}, _uri, socket) do
    {:noreply, load_text(socket, text_id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  defp load_text(socket, text_id) do
    user = current_user(socket)

    case Library.get_text(user, text_id) do
      nil ->
        put_flash(socket, :error, "文本不存在")

      text ->
        segments = segment_content(text.content)

        assign(socket,
          input_text: text.content,
          segments: segments,
          current_text_id: text.id,
          known_words: Vocabulary.known_words_with_understanding(user),
          selected_words: MapSet.new()
        )
    end
  end

  defp segment_content(content) do
    if String.trim(content) != "", do: Language.segment(content), else: []
  end

  @impl true
  def handle_event("update_text", params, socket) do
    user = current_user(socket)
    text = params["text"] || ""

    if String.trim(text) == "" do
      {:noreply, assign(socket, input_text: text, segments: [], selected_words: MapSet.new())}
    else
      segments = Language.segment(text)
      known_words = Vocabulary.known_words_with_understanding(user)

      {:noreply,
       assign(socket,
         input_text: text,
         segments: segments,
         known_words: known_words,
         selected_words: MapSet.new()
       )}
    end
  end

  @impl true
  def handle_event("toggle_word", %{"word" => word}, socket) do
    selected = socket.assigns.selected_words

    selected =
      if MapSet.member?(selected, word) do
        MapSet.delete(selected, word)
      else
        MapSet.put(selected, word)
      end

    {:noreply, assign(socket, selected_words: selected)}
  end

  @impl true
  def handle_event("select_all_unknown", _, socket) do
    known_words = socket.assigns.known_words

    unknown_words =
      socket.assigns.segments
      |> Enum.filter(&word?/1)
      |> Enum.map(&get_word/1)
      |> Enum.uniq()
      |> Enum.reject(&Map.has_key?(known_words, &1))
      |> MapSet.new()

    {:noreply, assign(socket, selected_words: unknown_words)}
  end

  @impl true
  def handle_event("show_concept", %{"word" => word}, socket) do
    user = current_user(socket)

    case Vocabulary.get_concept_by_word(user, word) do
      nil -> {:noreply, socket}
      concept -> {:noreply, assign(socket, expanded_concept: concept)}
    end
  end

  @impl true
  def handle_event("collapse", _, socket) do
    {:noreply, assign(socket, expanded_concept: nil)}
  end

  @impl true
  def handle_event("save_text", _, socket) do
    text = socket.assigns.input_text

    if String.trim(text) == "" do
      {:noreply, put_flash(socket, :error, "没有文本可保存")}
    else
      {:noreply, save_text(socket, text)}
    end
  end

  @impl true
  def handle_event("toggle_load_menu", _, socket) do
    {:noreply, assign(socket, show_load_menu: !socket.assigns.show_load_menu)}
  end

  @impl true
  def handle_event("close_load_menu", _, socket) do
    {:noreply, assign(socket, show_load_menu: false)}
  end

  @impl true
  def handle_event("toggle_hsk", _, socket) do
    {:noreply, assign(socket, show_hsk: !socket.assigns.show_hsk)}
  end

  @impl true
  def handle_event("new_text", _, socket) do
    {:noreply,
     assign(socket,
       input_text: "",
       segments: [],
       selected_words: MapSet.new(),
       current_text_id: nil,
       show_load_menu: false
     )}
  end

  @impl true
  def handle_event("add_selected", _, socket) do
    user = current_user(socket)
    selected = socket.assigns.selected_words |> MapSet.to_list()
    context = socket.assigns.input_text

    if Enum.empty?(selected) do
      {:noreply, put_flash(socket, :error, "No words selected")}
    else
      # Track which words are being imported, clear selection so user can continue
      {:noreply,
       socket
       |> assign(
         importing_words: socket.assigns.importing_words ++ selected,
         selected_words: MapSet.new()
       )
       |> start_async({:add_words, selected}, fn ->
         WordImporter.import_words(user, selected, context)
       end)}
    end
  end

  @impl true
  def handle_async({:add_words, words}, {:ok, {added, failed}}, socket) do
    user = current_user(socket)
    known_words = Vocabulary.known_words_with_understanding(user)

    # Remove these words from importing list
    importing_words = socket.assigns.importing_words -- words

    # Trigger background question generation for new words
    unless Enum.empty?(added) do
      Langseed.Workers.QuestionGenerator.enqueue()
    end

    socket =
      socket
      |> assign(
        importing_words: importing_words,
        known_words: known_words
      )

    socket =
      if Enum.empty?(added) do
        socket
      else
        put_flash(socket, :info, "添加了 #{length(added)} 个词: #{Enum.join(added, ", ")}")
      end

    socket =
      if Enum.empty?(failed) do
        socket
      else
        put_flash(socket, :error, "添加失败: #{Enum.join(failed, ", ")}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_async({:add_words, words}, {:exit, reason}, socket) do
    # Remove failed words from importing list
    importing_words = socket.assigns.importing_words -- words

    {:noreply,
     socket
     |> assign(importing_words: importing_words)
     |> put_flash(:error, "添加出错: #{inspect(reason)}")}
  end

  defp word?({:word, _}), do: true
  defp word?(_), do: false

  defp get_word({_, word}), do: word

  defp save_text(socket, text) do
    user = current_user(socket)

    case do_save_text(user, socket.assigns.current_text_id, text) do
      {:created, saved_text} ->
        socket
        |> assign(
          current_text_id: saved_text.id,
          recent_texts: Library.list_recent_texts(user, 5)
        )
        |> put_flash(:info, "已保存: #{saved_text.title}")

      {:updated, _} ->
        socket
        |> assign(recent_texts: Library.list_recent_texts(user, 5))
        |> put_flash(:info, "已更新")

      {:error, :create} ->
        put_flash(socket, :error, "保存失败")

      {:error, :update} ->
        put_flash(socket, :error, "更新失败")
    end
  end

  defp do_save_text(user, nil, text) do
    case Library.create_text(user, %{content: text}) do
      {:ok, saved_text} -> {:created, saved_text}
      {:error, _} -> {:error, :create}
    end
  end

  defp do_save_text(user, text_id, text) do
    text_record = Library.get_text!(user, text_id)

    case Library.update_text(text_record, %{content: text}) do
      {:ok, updated} -> {:updated, updated}
      {:error, _} -> {:error, :update}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4">
        <h1 class="text-2xl font-bold mb-4">分析</h1>

        <form phx-change="update_text">
          <textarea
            class="textarea textarea-bordered w-full h-48 text-xl"
            placeholder="输入中文..."
            name="text"
            phx-debounce="300"
          >{@input_text}</textarea>
        </form>

        <div class="flex items-center justify-between mb-4">
          <div class="flex gap-2">
            <button
              class="btn btn-sm btn-outline"
              phx-click="save_text"
              disabled={String.trim(@input_text) == ""}
            >
              <.icon name="hero-bookmark" class="size-4" />
              {if @current_text_id, do: "更新", else: "保存"}
            </button>

            <div class="relative">
              <button
                class="btn btn-sm btn-outline"
                phx-click="toggle_load_menu"
              >
                <.icon name="hero-folder-open" class="size-4" /> 加载
              </button>

              <%= if @show_load_menu do %>
                <div
                  class="fixed inset-0 z-40"
                  phx-click="close_load_menu"
                />
                <div class="absolute left-0 top-full mt-1 z-50 bg-base-100 shadow-lg rounded-lg border border-base-300 min-w-48">
                  <ul class="menu menu-sm p-1">
                    <li>
                      <button phx-click="new_text" class="font-semibold">
                        <.icon name="hero-plus" class="size-4" /> 新文本
                      </button>
                    </li>
                    <%= if length(@recent_texts) > 0 do %>
                      <li class="menu-title text-xs opacity-50 pt-2">最近</li>
                      <%= for text <- @recent_texts do %>
                        <li>
                          <a href={"/analyze?text_id=#{text.id}"} class="truncate max-w-48">
                            {text.title}
                          </a>
                        </li>
                      <% end %>
                      <li class="pt-1">
                        <a href="/texts" class="text-primary">
                          <.icon name="hero-ellipsis-horizontal" class="size-4" /> 查看全部
                        </a>
                      </li>
                    <% else %>
                      <li class="text-xs opacity-50 p-2">没有保存的文本</li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>

          <%= if @current_text_id do %>
            <span class="text-xs opacity-50">已保存</span>
          <% end %>
        </div>

        <%= if length(@segments) > 0 do %>
          <% words_only = @segments |> Enum.filter(&word?/1) |> Enum.map(&get_word/1) %>
          <% unique_words = words_only |> Enum.uniq() %>
          <% known_count = Enum.count(unique_words, &Map.has_key?(@known_words, &1)) %>
          <% unknown_count = length(unique_words) - known_count %>

          <div class="mb-4">
            <div class="flex items-center justify-between mb-3">
              <div class="flex items-center gap-3 text-sm">
                <span class="flex items-center gap-1">
                  <span
                    class="inline-block w-3 h-3 rounded"
                    style="background: linear-gradient(to right, #ef4444, #eab308, #22c55e)"
                  >
                  </span>
                  知道: {known_count}
                </span>
                <span class="flex items-center gap-1">
                  <span class="inline-block w-3 h-3 rounded bg-base-content"></span>
                  不知道: {unknown_count}
                </span>
                <label class="flex items-center gap-1 cursor-pointer">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-xs"
                    checked={@show_hsk}
                    phx-click="toggle_hsk"
                  />
                  <span class="text-xs opacity-70">HSK</span>
                </label>
              </div>
              <%= if unknown_count > 0 do %>
                <button
                  class="btn btn-xs btn-outline"
                  phx-click="select_all_unknown"
                >
                  全选不知道
                </button>
              <% end %>
            </div>

            <div class="text-3xl leading-relaxed">
              <%= for segment <- @segments do %>
                <.segment_inline
                  segment={segment}
                  known_words={@known_words}
                  selected_words={@selected_words}
                  importing_words={@importing_words}
                  show_hsk={@show_hsk}
                />
              <% end %>
            </div>
          </div>

          <%= if MapSet.size(@selected_words) > 0 || length(@importing_words) > 0 do %>
            <div class="fixed bottom-0 left-0 right-0 p-4 bg-base-200 border-t border-base-300">
              <div class="flex gap-2">
                <%= if MapSet.size(@selected_words) > 0 do %>
                  <button
                    class="btn btn-success flex-1"
                    phx-click="add_selected"
                  >
                    <.icon name="hero-plus" class="size-5" /> 添加 {MapSet.size(@selected_words)} 个词
                  </button>
                <% end %>
                <%= if length(@importing_words) > 0 do %>
                  <div class={[
                    "flex items-center gap-2 px-4 py-2 bg-info/20 rounded-lg text-info",
                    MapSet.size(@selected_words) == 0 && "flex-1 justify-center"
                  ]}>
                    <span class="loading loading-spinner loading-sm"></span>
                    <span>添加中 {length(@importing_words)} 个...</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>

        <%= if @expanded_concept do %>
          <div
            class="fixed inset-0 bg-black/50 z-40"
            phx-click="collapse"
          />
          <.concept_card concept={@expanded_concept} />
        <% end %>
      </div>
    </div>
    """
  end
end

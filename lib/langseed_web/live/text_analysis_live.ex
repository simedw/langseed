defmodule LangseedWeb.TextAnalysisLive do
  use LangseedWeb, :live_view

  alias Langseed.Vocabulary
  alias Langseed.Library
  alias Langseed.LLM

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Analyze",
       input_text: "",
       segments: [],
       selected_words: MapSet.new(),
       known_words: Vocabulary.known_words(),
       analyzing: false,
       adding: false,
       expanded_concept: nil,
       current_text_id: nil,
       recent_texts: Library.list_recent_texts(5),
       show_load_menu: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"text_id" => text_id} ->
        case Library.get_text(text_id) do
          nil ->
            {:noreply, put_flash(socket, :error, "文本不存在")}

          text ->
            segments =
              if String.trim(text.content) != "", do: segment_text(text.content), else: []

            {:noreply,
             assign(socket,
               input_text: text.content,
               segments: segments,
               current_text_id: text.id,
               known_words: Vocabulary.known_words(),
               selected_words: MapSet.new()
             )}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_text", params, socket) do
    # phx-change on standalone element sends name => value
    text = params["text"] || ""

    # Auto-analyze on text change
    if String.trim(text) == "" do
      {:noreply, assign(socket, input_text: text, segments: [], selected_words: MapSet.new())}
    else
      segments = segment_text(text)
      known_words = Vocabulary.known_words()

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
      |> Enum.filter(&is_word?/1)
      |> Enum.map(&get_word/1)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(known_words, &1))
      |> MapSet.new()

    {:noreply, assign(socket, selected_words: unknown_words)}
  end

  @impl true
  def handle_event("show_concept", %{"word" => word}, socket) do
    case Vocabulary.get_concept_by_word(word) do
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
      case socket.assigns.current_text_id do
        nil ->
          # Create new text
          case Library.create_text(%{content: text}) do
            {:ok, saved_text} ->
              {:noreply,
               socket
               |> assign(
                 current_text_id: saved_text.id,
                 recent_texts: Library.list_recent_texts(5)
               )
               |> put_flash(:info, "已保存: #{saved_text.title}")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "保存失败")}
          end

        text_id ->
          # Update existing text
          text_record = Library.get_text!(text_id)

          case Library.update_text(text_record, %{content: text}) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(recent_texts: Library.list_recent_texts(5))
               |> put_flash(:info, "已更新")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "更新失败")}
          end
      end
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
    selected = socket.assigns.selected_words |> MapSet.to_list()
    context = socket.assigns.input_text

    if length(selected) == 0 do
      {:noreply, put_flash(socket, :error, "No words selected")}
    else
      {:noreply,
       socket
       |> assign(adding: true)
       |> start_async(:add_words, fn -> add_words_with_llm(selected, context) end)}
    end
  end

  @impl true
  def handle_async(:add_words, {:ok, {added, failed}}, socket) do
    known_words = Vocabulary.known_words()

    socket =
      socket
      |> assign(
        adding: false,
        selected_words: MapSet.new(),
        known_words: known_words
      )

    socket =
      if length(added) > 0 do
        put_flash(socket, :info, "Added #{length(added)} words: #{Enum.join(added, ", ")}")
      else
        socket
      end

    socket =
      if length(failed) > 0 do
        put_flash(socket, :error, "Failed to add: #{Enum.join(failed, ", ")}")
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_async(:add_words, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(adding: false)
     |> put_flash(:error, "Error adding words: #{inspect(reason)}")}
  end

  defp segment_text(text) do
    # Use Jieba for word segmentation, but preserve punctuation and newlines
    {:ok, jieba} = Jieba.new()

    # Split by newlines first to preserve them, then segment each line
    text
    |> String.split(~r/(\n)/, include_captures: true)
    |> Enum.flat_map(fn part ->
      if part == "\n" do
        [{:newline, "\n"}]
      else
        jieba
        |> Jieba.cut(part)
        |> Enum.map(fn word ->
          cond do
            String.trim(word) == "" -> {:space, word}
            Regex.match?(~r/^[\p{P}\p{S}]+$/u, word) -> {:punct, word}
            true -> {:word, word}
          end
        end)
      end
    end)
  end

  defp is_word?({:word, _}), do: true
  defp is_word?(_), do: false

  defp get_word({_, word}), do: word

  defp add_words_with_llm(words, context) do
    # Get current known words to pass to LLM for explanation generation
    known_words = Vocabulary.known_words()

    results =
      Enum.map(words, fn word ->
        # Extract just the sentence containing the word
        sentence = extract_sentence(context, word)

        case LLM.analyze_word(word, sentence, known_words) do
          {:ok, analysis} ->
            attrs = %{
              word: word,
              pinyin: analysis.pinyin,
              meaning: analysis.meaning,
              part_of_speech: analysis.part_of_speech,
              explanation: analysis.explanation,
              explanation_quality: analysis.explanation_quality,
              desired_words: analysis.desired_words,
              example_sentence: sentence,
              understanding: 0
            }

            case Vocabulary.create_concept(attrs) do
              {:ok, _concept} -> {:ok, word}
              {:error, _} -> {:error, word}
            end

          {:error, _reason} ->
            # Fallback: create with placeholder values
            attrs = %{
              word: word,
              pinyin: "?",
              meaning: "?",
              part_of_speech: "other",
              explanation: "❓",
              explanation_quality: 1,
              desired_words: [],
              example_sentence: sentence,
              understanding: 0
            }

            case Vocabulary.create_concept(attrs) do
              {:ok, _concept} -> {:ok, word}
              {:error, _} -> {:error, word}
            end
        end
      end)

    added = Enum.filter(results, fn {status, _} -> status == :ok end) |> Enum.map(&elem(&1, 1))

    failed =
      Enum.filter(results, fn {status, _} -> status == :error end) |> Enum.map(&elem(&1, 1))

    {added, failed}
  end

  # Extract the sentence containing the word from the full text
  defp extract_sentence(text, word) do
    # Split by common Chinese sentence endings (Elixir strings are UTF-8 by default)
    sentences =
      text
      |> String.split(~r/[。！？\n]+/, trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Find the first sentence containing the word, fallback to first sentence
    case Enum.find(sentences, fn s -> String.contains?(s, word) end) do
      nil -> List.first(sentences) || word
      found -> found
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
          <% words_only = @segments |> Enum.filter(&is_word?/1) |> Enum.map(&get_word/1) %>
          <% unique_words = words_only |> Enum.uniq() %>
          <% known_count = Enum.count(unique_words, &MapSet.member?(@known_words, &1)) %>
          <% unknown_count = length(unique_words) - known_count %>

          <div class="mb-4">
            <div class="flex items-center justify-between mb-3">
              <div class="flex gap-3 text-sm">
                <span class="flex items-center gap-1">
                  <span class="inline-block w-3 h-3 rounded bg-success"></span> 知道: {known_count}
                </span>
                <span class="flex items-center gap-1">
                  <span class="inline-block w-3 h-3 rounded bg-warning"></span> 不知道: {unknown_count}
                </span>
              </div>
              <%= if unknown_count > 0 do %>
                <button
                  class="btn btn-xs btn-warning btn-outline"
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
                />
              <% end %>
            </div>
          </div>

          <%= if MapSet.size(@selected_words) > 0 do %>
            <div class="fixed bottom-0 left-0 right-0 p-4 bg-base-200 border-t border-base-300">
              <button
                class="btn btn-success w-full"
                phx-click="add_selected"
                disabled={@adding}
              >
                <%= if @adding do %>
                  <span class="loading loading-spinner loading-sm mr-2"></span> 添加中...
                <% else %>
                  <.icon name="hero-plus" class="size-5 mr-2" /> 添加 {MapSet.size(@selected_words)} 个词
                <% end %>
              </button>
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

  defp concept_card(assigns) do
    ~H"""
    <div class="fixed inset-x-4 top-1/2 -translate-y-1/2 z-50 max-w-md mx-auto">
      <div
        class="card bg-base-100 shadow-2xl"
        style={"border-left: 6px solid #{understanding_color(@concept.understanding)}"}
      >
        <div class="card-body p-5">
          <div class="flex items-start justify-between">
            <div>
              <span class="text-4xl font-bold">{@concept.word}</span>
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

          <%= if @concept.explanation do %>
            <div class="mt-4 p-3 bg-base-200 rounded-lg">
              <p class="text-xl">
                {@concept.explanation}
              </p>
              <%= if @concept.explanation_quality do %>
                <div class="flex items-center gap-1 mt-2 text-sm opacity-60">
                  <span>解释质量:</span>
                  <.quality_stars quality={@concept.explanation_quality} />
                </div>
              <% end %>
            </div>
          <% end %>

          <details class="mt-3">
            <summary class="text-xs opacity-40 cursor-pointer hover:opacity-60">
              👁️ 英文
            </summary>
            <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
          </details>
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
    cond do
      level < 50 ->
        ratio = level / 50
        r = 239
        g = round(68 + (171 - 68) * ratio)
        b = round(68 + (8 - 68) * ratio)
        "rgb(#{r}, #{g}, #{b})"

      true ->
        ratio = (level - 50) / 50
        r = round(234 - (234 - 34) * ratio)
        g = round(179 + (197 - 179) * ratio)
        b = round(8 + (94 - 8) * ratio)
        "rgb(#{r}, #{g}, #{b})"
    end
  end

  defp segment_inline(%{segment: {:newline, _}} = assigns) do
    ~H"<br />"
  end

  defp segment_inline(%{segment: {:space, text}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H"<span>{@text}</span>"
  end

  defp segment_inline(%{segment: {:punct, text}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H"<span class=\"opacity-60\">{@text}</span>"
  end

  defp segment_inline(%{segment: {:word, word}} = assigns) do
    known = MapSet.member?(assigns.known_words, word)
    selected = MapSet.member?(assigns.selected_words, word)
    assigns = assign(assigns, word: word, known: known, selected: selected)

    ~H"""
    <%= if @known do %>
      <span
        class="text-success cursor-pointer hover:underline"
        phx-click="show_concept"
        phx-value-word={@word}
      >
        {@word}
      </span>
    <% else %>
      <span
        class={"cursor-pointer transition-colors #{if @selected, do: "text-warning font-bold underline decoration-2", else: "text-warning/70 hover:text-warning"}"}
        phx-click="toggle_word"
        phx-value-word={@word}
      >
        {@word}
      </span>
    <% end %>
    """
  end
end

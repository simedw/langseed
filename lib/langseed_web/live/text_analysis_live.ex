defmodule LangseedWeb.TextAnalysisLive do
  use LangseedWeb, :live_view
  use LangseedWeb.AudioHelpers
  use LangseedWeb.WordImportHelpers

  import LangseedWeb.TextAnalysisComponents

  alias Langseed.Vocabulary
  alias Langseed.Vocabulary.WordImports
  alias Langseed.Library
  alias Langseed.Language

  @impl true
  def mount(_params, _session, socket) do
    scope = current_scope(socket)

    {:ok,
     assign(socket,
       page_title: gettext("Analyze"),
       input_text: "",
       segments: [],
       selected_words: MapSet.new(),
       known_words: Vocabulary.known_words_with_understanding(scope),
       analyzing: false,
       expanded_concept: nil,
       current_text_id: nil,
       recent_texts: Library.list_recent_texts(scope, 5),
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
    scope = current_scope(socket)

    case Library.get_text(scope, text_id) do
      nil ->
        put_flash(socket, :error, "Text not found")

      text ->
        segments = segment_content(text.content, scope.language)
        known_words = Vocabulary.known_words_with_understanding(scope)

        socket =
          assign(socket,
            input_text: text.content,
            segments: segments,
            current_text_id: text.id,
            known_words: known_words,
            selected_words: MapSet.new()
          )

        # Push content to editor (skip_cursor since this is loading, not typing)
        html = render_segments_html(segments, known_words, socket.assigns)

        push_event(socket, "editor-content", %{
          html: html,
          empty: false,
          text: text.content,
          skip_cursor: true
        })
    end
  end

  defp segment_content(content, language) do
    if String.trim(content) != "", do: Language.segment(content, language), else: []
  end

  @impl true
  def handle_event("update_text", params, socket) do
    scope = current_scope(socket)
    text = params["text"] || ""

    if String.trim(text) == "" do
      {:noreply,
       socket
       |> assign(input_text: text, segments: [], selected_words: MapSet.new())
       |> push_event("editor-content", %{html: "", empty: true, text: text})}
    else
      segments = Language.segment(text, scope.language)
      known_words = Vocabulary.known_words_with_understanding(scope)

      # Render segments to HTML for the inline editor
      socket =
        assign(socket,
          input_text: text,
          segments: segments,
          known_words: known_words,
          selected_words: MapSet.new()
        )

      html = render_segments_html(segments, known_words, socket.assigns)

      {:noreply,
       socket
       |> push_event("editor-content", %{html: html, empty: false, text: text})}
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

    socket = assign(socket, selected_words: selected)

    # Re-push styled content to reflect selection change
    html =
      render_segments_html(
        socket.assigns.segments,
        socket.assigns.known_words,
        socket.assigns
      )

    {:noreply,
     push_event(socket, "editor-content", %{
       html: html,
       empty: false,
       text: socket.assigns.input_text,
       skip_cursor: true
     })}
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

    socket = assign(socket, selected_words: unknown_words)

    # Re-push styled content to reflect selection change
    html =
      render_segments_html(
        socket.assigns.segments,
        socket.assigns.known_words,
        socket.assigns
      )

    {:noreply,
     push_event(socket, "editor-content", %{
       html: html,
       empty: false,
       text: socket.assigns.input_text,
       skip_cursor: true
     })}
  end

  @impl true
  def handle_event("show_concept", %{"word" => word}, socket) do
    scope = current_scope(socket)

    case Vocabulary.get_concept_by_word(scope, word) do
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
      {:noreply, put_flash(socket, :error, gettext("No text to save"))}
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
    # HSK is only relevant for Chinese
    scope = current_scope(socket)

    if scope && scope.language == "zh" do
      {:noreply, assign(socket, show_hsk: !socket.assigns.show_hsk)}
    else
      {:noreply, socket}
    end
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
    scope = current_scope(socket)
    selected = socket.assigns.selected_words |> MapSet.to_list()
    context = socket.assigns.input_text

    if Enum.empty?(selected) do
      {:noreply, put_flash(socket, :error, "No words selected")}
    else
      # Enqueue words for async import - this is fire and forget
      # Words will be imported in the background by Oban worker
      {:ok, _imports} = WordImports.enqueue_words(scope, selected, context)

      # Clear selection so user can continue selecting more
      {:noreply,
       socket
       |> assign(selected_words: MapSet.new())
       |> put_flash(:info, gettext("Queued %{count} words for import", count: length(selected)))}
    end
  end

  @impl true
  def handle_event("mark_as_known", _, socket) do
    scope = current_scope(socket)
    selected = socket.assigns.selected_words |> MapSet.to_list()

    if Enum.empty?(selected) do
      {:noreply, put_flash(socket, :error, "No words selected")}
    else
      case Vocabulary.mark_words_as_known(scope, selected) do
        {:ok, count} ->
          known_words = Vocabulary.known_words_with_understanding(scope)

          {:noreply,
           socket
           |> assign(
             selected_words: MapSet.new(),
             known_words: known_words
           )
           |> put_flash(:info, gettext("Marked %{count} words as known", count: count))}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  # Handle practice_ready check (scheduled by user_auth on mount)
  @impl true
  def handle_info(:check_practice_ready, socket) do
    # Reschedule and update practice_ready indicator
    Process.send_after(self(), :check_practice_ready, 30_000)
    scope = current_scope(socket)
    practice_ready = Langseed.Practice.has_practice_ready?(scope)
    {:noreply, assign(socket, :practice_ready, practice_ready)}
  end

  defp word?({:word, _}), do: true
  defp word?(_), do: false

  defp get_word({_, word}), do: word

  # Render segments to HTML string for the inline editor
  defp render_segments_html(segments, known_words, assigns) do
    segments
    |> Enum.map(&render_segment(&1, known_words, assigns))
    |> Enum.join("")
  end

  defp render_segment({:newline, _}, _known_words, _assigns), do: "<br>"
  defp render_segment({:space, text}, _known_words, _assigns), do: escape_html(text)

  defp render_segment({:punct, text}, _known_words, _assigns) do
    ~s(<span class="opacity-60">#{escape_html(text)}</span>)
  end

  defp render_segment({:word, word}, known_words, assigns) do
    understanding = Map.get(known_words, word)

    if understanding do
      render_known_word(word, understanding)
    else
      render_unknown_word(word, assigns.selected_words)
    end
  end

  defp render_known_word(word, understanding) do
    import LangseedWeb.SharedComponents, only: [understanding_color: 1]
    color = understanding_color(understanding)

    ~s(<span class="cursor-pointer hover:underline" style="color: #{color}" ) <>
      ~s(data-word="#{escape_html(word)}" data-action="show">#{escape_html(word)}</span>)
  end

  defp render_unknown_word(word, selected_words) do
    classes =
      if MapSet.member?(selected_words, word) do
        "cursor-pointer text-primary font-bold underline decoration-2"
      else
        "cursor-pointer text-base-content hover:text-primary"
      end

    ~s(<span class="#{classes}" ) <>
      ~s(data-word="#{escape_html(word)}" data-action="toggle">#{escape_html(word)}</span>)
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp save_text(socket, text) do
    scope = current_scope(socket)

    case do_save_text(scope, socket.assigns.current_text_id, text) do
      {:created, saved_text} ->
        socket
        |> assign(
          current_text_id: saved_text.id,
          recent_texts: Library.list_recent_texts(scope, 5)
        )
        |> put_flash(:info, gettext("Saved: %{title}", title: saved_text.title))

      {:updated, _} ->
        socket
        |> assign(recent_texts: Library.list_recent_texts(scope, 5))
        |> put_flash(:info, gettext("Updated"))

      {:error, :create} ->
        put_flash(socket, :error, gettext("Save failed"))

      {:error, :update} ->
        put_flash(socket, :error, gettext("Update failed"))
    end
  end

  defp do_save_text(scope, nil, text) do
    case Library.create_text(scope, %{content: text}) do
      {:ok, saved_text} -> {:created, saved_text}
      {:error, _} -> {:error, :create}
    end
  end

  defp do_save_text(scope, text_id, text) do
    text_record = Library.get_text!(scope, text_id)

    case Library.update_text(text_record, %{content: text}) do
      {:ok, updated} -> {:updated, updated}
      {:error, _} -> {:error, :update}
    end
  end

  @impl true
  def render(assigns) do
    # Pre-calculate stats for the template
    words_only =
      assigns.segments |> Enum.filter(&word?/1) |> Enum.map(&get_word/1)

    unique_words = words_only |> Enum.uniq()
    known_count = Enum.count(unique_words, &Map.has_key?(assigns.known_words, &1))
    unknown_count = length(unique_words) - known_count
    has_segments = not Enum.empty?(assigns.segments)

    assigns =
      assign(assigns,
        known_count: known_count,
        unknown_count: unknown_count,
        has_segments: has_segments
      )

    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4">
        <%!-- Toolbar --%>
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-3">
            <h1 class="text-xl font-bold opacity-70">{gettext("Analyze")}</h1>

            <%= if @has_segments do %>
              <div class="flex items-center gap-3 text-sm">
                <span class="flex items-center gap-1">
                  <span
                    class="inline-block w-2.5 h-2.5 rounded-full"
                    style="background: linear-gradient(to right, #ef4444, #eab308, #22c55e)"
                  >
                  </span>
                  <span class="opacity-70">{@known_count}</span>
                </span>
                <span class="flex items-center gap-1">
                  <span class="inline-block w-2.5 h-2.5 rounded-full bg-base-content/50"></span>
                  <span class="opacity-70">{@unknown_count}</span>
                </span>
                <%= if @current_scope && @current_scope.language == "zh" do %>
                  <label class="flex items-center gap-1 cursor-pointer">
                    <input
                      type="checkbox"
                      class="checkbox checkbox-xs"
                      checked={@show_hsk}
                      phx-click="toggle_hsk"
                    />
                    <span class="text-xs opacity-50">HSK</span>
                  </label>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="flex items-center gap-2">
            <%= if @unknown_count > 0 do %>
              <button
                class="btn btn-xs btn-ghost opacity-70"
                phx-click="select_all_unknown"
              >
                {gettext("Select all unknown")}
              </button>
            <% end %>

            <button
              class="btn btn-sm btn-ghost"
              phx-click="save_text"
              disabled={String.trim(@input_text) == ""}
              title={if @current_text_id, do: gettext("Update"), else: gettext("Save")}
            >
              <.icon name="hero-bookmark" class="size-4" />
            </button>

            <div class="relative">
              <button
                class="btn btn-sm btn-ghost"
                phx-click="toggle_load_menu"
                title={gettext("Load")}
              >
                <.icon name="hero-folder-open" class="size-4" />
              </button>

              <%= if @show_load_menu do %>
                <div
                  class="fixed inset-0 z-40"
                  phx-click="close_load_menu"
                />
                <div class="absolute right-0 top-full mt-1 z-50 bg-base-100 shadow-lg rounded-lg border border-base-300 min-w-48">
                  <ul class="menu menu-sm p-1">
                    <li>
                      <button phx-click="new_text" class="font-semibold">
                        <.icon name="hero-plus" class="size-4" /> {gettext("New text")}
                      </button>
                    </li>
                    <%= if length(@recent_texts) > 0 do %>
                      <li class="menu-title text-xs opacity-50 pt-2">{gettext("Recent")}</li>
                      <%= for text <- @recent_texts do %>
                        <li>
                          <a href={"/analyze?text_id=#{text.id}"} class="truncate max-w-48">
                            {text.title}
                          </a>
                        </li>
                      <% end %>
                      <li class="pt-1">
                        <a href="/texts" class="text-primary">
                          <.icon name="hero-ellipsis-horizontal" class="size-4" /> {gettext(
                            "View all"
                          )}
                        </a>
                      </li>
                    <% else %>
                      <li class="text-xs opacity-50 p-2">{gettext("No saved texts")}</li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Inline Editor --%>
        <div
          id="inline-editor"
          phx-hook=".InlineTextEditor"
          phx-update="ignore"
          class="min-h-[60vh] text-2xl leading-relaxed outline-none focus:outline-none"
          contenteditable="true"
          data-placeholder={gettext("Start typing or paste text to analyze...")}
          data-input-text={@input_text}
        >
          <%= if @input_text == "" do %>
            <span class="opacity-40">{gettext("Start typing or paste text to analyze...")}</span>
          <% else %>
            <%= for segment <- @segments do %>
              <.segment_inline
                segment={segment}
                known_words={@known_words}
                selected_words={@selected_words}
                show_hsk={@show_hsk}
              />
            <% end %>
          <% end %>
        </div>

        <%!-- Bottom Action Bar --%>
        <%= if MapSet.size(@selected_words) > 0 do %>
          <div class="fixed bottom-16 md:bottom-0 left-0 right-0 p-4 bg-base-200 border-t border-base-300">
            <div class="flex gap-2">
              <button
                class="btn btn-success flex-1"
                phx-click="add_selected"
              >
                <.icon name="hero-plus" class="size-5" /> {gettext("Add %{count} words",
                  count: MapSet.size(@selected_words)
                )}
              </button>
              <button
                class="btn btn-outline btn-primary"
                phx-click="mark_as_known"
                title={gettext("Mark as already known (100%)")}
              >
                <.icon name="hero-check-badge" class="size-5" /> {gettext("Known")}
              </button>
            </div>
          </div>
        <% end %>

        <%!-- Concept Card Modal --%>
        <%= if @expanded_concept do %>
          <div
            class="fixed inset-0 bg-black/50 z-40"
            phx-click="collapse"
          />
          <.concept_card concept={@expanded_concept} />
        <% end %>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".InlineTextEditor">
      export default {
        mounted() {
          // Track state
          this.pendingText = null  // Text we sent to server, awaiting response
          this.isComposing = false

          // Listen for any changes
          this.el.addEventListener("input", () => this.scheduleUpdate())
          this.el.addEventListener("focus", () => this.handleFocus())
          this.el.addEventListener("blur", () => this.handleBlur())

          // IME composition - wait until done
          this.el.addEventListener("compositionstart", () => {
            this.isComposing = true
          })
          this.el.addEventListener("compositionend", () => {
            this.isComposing = false
            this.scheduleUpdate()
          })

          // Word clicks - use mousedown to prevent focus before it happens
          this.el.addEventListener("mousedown", (e) => this.handleWordMousedown(e))
          this.el.addEventListener("click", (e) => this.handleWordClick(e))

          // Handle styled content from server
          this.handleEvent("editor-content", ({html, empty, text: serverText, skip_cursor}) => {
            // Don't update during IME composition
            if (this.isComposing) return

            // Only check for stale text during typing (not for word clicks/selections)
            if (!skip_cursor && serverText) {
              const currentText = this.getText()
              if (currentText !== serverText) {
                // Text changed since we sent - ignore this response, new update pending
                return
              }
            }

            // Clear pending since we're applying this update
            this.pendingText = null

            // Save cursor position (only if we'll restore it)
            let cursorOffset = 0
            if (!skip_cursor && document.activeElement === this.el) {
              const selection = window.getSelection()
              if (selection.rangeCount > 0) {
                const range = selection.getRangeAt(0)
                cursorOffset = this.getTextOffset(range.startContainer, range.startOffset)
              }
            }

            // Update content
            if (empty) {
              if (document.activeElement !== this.el) {
                this.el.innerHTML = `<span class="opacity-40">${this.el.dataset.placeholder}</span>`
              } else {
                this.el.innerHTML = ""
              }
            } else {
              this.el.innerHTML = html
            }

            // Restore cursor if element is focused and not a click action
            if (!skip_cursor && document.activeElement === this.el && !empty) {
              this.restoreCursor(cursorOffset)
            }
          })
        },

        scheduleUpdate() {
          // Wait 500ms of no changes, then send to server
          clearTimeout(this.debounce)
          this.debounce = setTimeout(() => {
            if (this.isComposing) return

            const text = this.getText()
            // Only send if different from what we last sent
            if (text !== this.pendingText) {
              this.pendingText = text
              this.pushEvent("update_text", { text })
            }
          }, 500)
        },

        handleWordMousedown(e) {
          // If clicking on a word, prevent focus from happening
          const target = e.target.closest("[data-word]")
          if (target) {
            e.preventDefault()
          }
        },

        handleWordClick(e) {
          const target = e.target.closest("[data-word]")
          if (!target) return

          const word = target.dataset.word
          const action = target.dataset.action

          if (action === "toggle") {
            this.pushEvent("toggle_word", { word })
          } else if (action === "show") {
            this.pushEvent("show_concept", { word })
          }
        },

        handleFocus() {
          // Clear placeholder
          const text = this.getText()
          if (text === "" || this.el.querySelector(".opacity-40")) {
            this.el.innerHTML = ""
          }
        },

        handleBlur() {
          if (this.getText() === "") {
            this.el.innerHTML = `<span class="opacity-40">${this.el.dataset.placeholder}</span>`
          }
        },

        getText() {
          const clone = this.el.cloneNode(true)
          clone.querySelectorAll("br").forEach(br => br.replaceWith("\n"))
          return clone.textContent || ""
        },

        getTextOffset(node, offset) {
          let total = 0
          const walker = document.createTreeWalker(
            this.el,
            NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT,
            null,
            false
          )

          while (walker.nextNode()) {
            const current = walker.currentNode
            if (current === node) {
              return total + offset
            }
            if (current.nodeType === Node.TEXT_NODE) {
              total += current.textContent.length
            } else if (current.nodeName === "BR") {
              total += 1
            }
          }
          return total
        },

        restoreCursor(offset) {
          const selection = window.getSelection()
          const range = document.createRange()

          let currentOffset = 0
          const walker = document.createTreeWalker(
            this.el,
            NodeFilter.SHOW_TEXT,
            null,
            false
          )

          let node = walker.nextNode()
          while (node) {
            const len = node.textContent.length
            if (currentOffset + len >= offset) {
              range.setStart(node, Math.min(offset - currentOffset, len))
              range.collapse(true)
              selection.removeAllRanges()
              selection.addRange(range)
              return
            }
            currentOffset += len
            node = walker.nextNode()
          }

          // Put cursor at end if position not found
          range.selectNodeContents(this.el)
          range.collapse(false)
          selection.removeAllRanges()
          selection.addRange(range)
        }
      }
    </script>
    """
  end
end

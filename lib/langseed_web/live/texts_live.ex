defmodule LangseedWeb.TextsLive do
  use LangseedWeb, :live_view

  alias Langseed.Library

  @impl true
  def mount(_params, _session, socket) do
    scope = current_scope(socket)

    socket =
      socket
      |> assign(
        page_title: gettext("Texts"),
        texts: Library.list_texts(scope),
        editing_id: nil,
        edit_title: "",
        show_upload_modal: false
      )
      |> allow_upload(:text_file,
        accept: ~w(.txt .md .markdown .text),
        max_entries: 1,
        max_file_size: 10_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = current_scope(socket)
    text = Library.get_text!(scope, id)
    {:ok, _} = Library.delete_text(text)

    {:noreply,
     socket
     |> assign(texts: Library.list_texts(scope))
     |> put_flash(:info, gettext("Deleted"))}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    scope = current_scope(socket)
    text = Library.get_text!(scope, id)
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
    scope = current_scope(socket)
    text = Library.get_text!(scope, id)
    {:ok, _} = Library.update_text(text, %{title: socket.assigns.edit_title})

    {:noreply,
     socket
     |> assign(texts: Library.list_texts(scope), editing_id: nil, edit_title: "")}
  end

  @impl true
  def handle_event("show_upload_modal", _, socket) do
    {:noreply, assign(socket, show_upload_modal: true)}
  end

  @impl true
  def handle_event("hide_upload_modal", _, socket) do
    {:noreply, assign(socket, show_upload_modal: false)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_file", _params, socket) do
    scope = current_scope(socket)

    uploaded_files =
      consume_uploaded_entries(socket, :text_file, fn %{path: path}, entry ->
        case File.read(path) do
          {:ok, content} ->
            # Extract filename without extension as the title
            title = Path.basename(entry.client_name, Path.extname(entry.client_name))

            # Create the text entry
            case Library.create_text(scope, %{content: content, title: title}) do
              {:ok, text} ->
                {:ok, text}

              {:error, _changeset} ->
                {:postpone, :error}
            end

          {:error, _reason} ->
            {:postpone, :error}
        end
      end)

    # consume_uploaded_entries returns the value from {:ok, value}, so we get [text] not [{:ok, text}]
    case uploaded_files do
      [%Langseed.Library.Text{} = _text] ->
        {:noreply,
         socket
         |> assign(texts: Library.list_texts(scope), show_upload_modal: false)
         |> put_flash(:info, gettext("Text added successfully"))}

      [] ->
        # No files to process (shouldn't happen normally)
        {:noreply, socket}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to add text"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="p-4">
        <h1 class="text-2xl font-bold mb-4">{gettext("Texts")}</h1>

        <%= if length(@texts) == 0 do %>
          <div class="text-center py-12">
            <p class="text-lg opacity-70">{gettext("No saved texts")}</p>
            <p class="text-sm opacity-50 mt-2">
              {gettext("Go to %{link} to save texts",
                link: ~s(<a href="/analyze" class="link link-primary">#{gettext("Analyze")}</a>)
              )
              |> Phoenix.HTML.raw()}
            </p>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for text <- @texts do %>
              <.text_card text={text} editing={@editing_id == text.id} edit_title={@edit_title} />
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Floating Action Button --%>
      <button
        phx-click="show_upload_modal"
        class="fixed bottom-6 right-6 btn btn-primary btn-circle btn-lg shadow-lg hover:shadow-xl transition-shadow"
        aria-label={gettext("Upload text")}
      >
        <.icon name="hero-arrow-up-tray" class="size-6" />
      </button>

      <%!-- Upload Modal --%>
      <%= if @show_upload_modal do %>
        <.upload_modal uploads={@uploads} />
      <% end %>
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
            <a href={"/analyze?text_id=#{@text.id}"} class="btn btn-sm btn-primary">
              <.icon name="hero-book-open" class="size-4" /> {gettext("Read")}
            </a>
            <%= unless @editing do %>
              <button class="btn btn-sm btn-ghost" phx-click="start_edit" phx-value-id={@text.id}>
                <.icon name="hero-pencil" class="size-4" />
              </button>
            <% end %>
            <button
              class="btn btn-sm btn-ghost text-error"
              phx-click="delete"
              phx-value-id={@text.id}
              data-confirm={gettext("Delete this text?")}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp upload_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <%!-- Background overlay --%>
      <div
        class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
        phx-click="hide_upload_modal"
      >
      </div>

      <%!-- Modal panel --%>
      <div class="flex min-h-full items-center justify-center p-4">
        <div class="relative transform overflow-hidden rounded-lg bg-base-100 shadow-xl transition-all w-full max-w-lg">
          <div class="bg-base-100 p-6">
            <%!-- Modal header --%>
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-xl font-semibold" id="modal-title">
                {gettext("Upload Text File")}
              </h3>
              <button
                type="button"
                phx-click="hide_upload_modal"
                class="btn btn-sm btn-ghost btn-circle"
                aria-label={gettext("Close")}
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>

            <%!-- Upload form --%>
            <form phx-submit="upload_file" phx-change="validate_upload" id="upload-form">
              <div class="space-y-4">
                <%!-- File input area with drag-and-drop support --%>
                <div
                  id="dropzone"
                  class="dropzone relative border-2 border-dashed rounded-lg p-8 text-center transition-colors cursor-pointer hover:border-primary hover:bg-base-200"
                  phx-drop-target={@uploads.text_file.ref}
                  phx-hook=".DropzoneHighlight"
                >
                  <.live_file_input upload={@uploads.text_file} class="sr-only" />
                  <div class="flex flex-col items-center gap-3 pointer-events-none">
                    <.icon name="hero-document-text" class="size-12 opacity-50" />
                    <div>
                      <p class="font-medium">{gettext("Choose a file or drag it here")}</p>
                      <p class="text-sm opacity-60 mt-1">
                        {gettext("Supported formats: .txt, .md, .markdown, .text")}
                      </p>
                      <p class="text-xs opacity-40 mt-1">
                        {gettext("Maximum file size: 10 MB")}
                      </p>
                    </div>
                  </div>
                  <%!-- Invisible overlay to capture clicks --%>
                  <label for={@uploads.text_file.ref} class="absolute inset-0 cursor-pointer"></label>
                </div>

                <%!-- Upload progress and errors --%>
                <%= for entry <- @uploads.text_file.entries do %>
                  <div class="space-y-2">
                    <div class="flex items-center gap-2">
                      <.icon name="hero-document-text" class="size-5 opacity-70" />
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium truncate">{entry.client_name}</p>
                        <p class="text-xs opacity-60">
                          {format_file_size(entry.client_size)}
                        </p>
                      </div>
                    </div>

                    <%!-- Progress bar --%>
                    <div class="w-full bg-base-200 rounded-full h-2">
                      <div
                        class="bg-primary h-2 rounded-full transition-all"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>

                    <%!-- Upload errors --%>
                    <%= for err <- upload_errors(@uploads.text_file, entry) do %>
                      <p class="text-error text-sm">
                        {error_to_string(err)}
                      </p>
                    <% end %>
                  </div>
                <% end %>

                <%!-- General upload errors --%>
                <%= for err <- upload_errors(@uploads.text_file) do %>
                  <p class="text-error text-sm">
                    {error_to_string(err)}
                  </p>
                <% end %>
              </div>

              <%!-- Modal actions --%>
              <div class="flex gap-2 justify-end mt-6">
                <button
                  type="button"
                  phx-click="hide_upload_modal"
                  class="btn btn-ghost"
                >
                  {gettext("Cancel")}
                </button>
                <button
                  type="submit"
                  class="btn btn-primary"
                  disabled={length(@uploads.text_file.entries) == 0}
                >
                  {gettext("Add")}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".DropzoneHighlight">
        export default {
          mounted() {
            let counter = 0;
            this.el.addEventListener("dragenter", (e) => {
              counter++;
              this.el.classList.add("border-primary", "bg-base-200", "scale-[1.02]");
            });
            this.el.addEventListener("dragleave", (e) => {
              counter--;
              if (counter === 0) {
                this.el.classList.remove("border-primary", "bg-base-200", "scale-[1.02]");
              }
            });
            this.el.addEventListener("drop", (e) => {
              counter = 0;
              this.el.classList.remove("border-primary", "bg-base-200", "scale-[1.02]");
            });
          }
        }
      </script>
    </div>
    """
  end

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / (1024 * 1024), 1)} MB"

  defp error_to_string(:too_large), do: gettext("File is too large (max 10 MB)")
  defp error_to_string(:not_accepted), do: gettext("File type not supported")
  defp error_to_string(:too_many_files), do: gettext("Only one file at a time")
  defp error_to_string(_), do: gettext("An error occurred")
end

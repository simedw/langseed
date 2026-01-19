defmodule LangseedWeb.WordImportHelpers do
  @moduledoc """
  Helper module for LiveViews to handle word import PubSub messages.

  Usage:
      use LangseedWeb.WordImportHelpers

  This must be placed AFTER all other handle_info definitions in the module
  to ensure the handlers are matched correctly.
  """

  defmacro __using__(_opts) do
    quote do
      # Handle word import progress updates - using @before_compile to inject at the end
      @before_compile LangseedWeb.WordImportHelpers
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Handle word import progress updates
      @impl true
      def handle_info({:word_import_update, %{count: count, processing: processing}}, socket) do
        {:noreply,
         socket
         |> Phoenix.Component.assign(:word_import_count, count)
         |> Phoenix.Component.assign(:word_import_processing, processing && processing.word)}
      end

      # Handle individual word imported notification
      @impl true
      def handle_info({:word_imported, %{word: _word}}, socket) do
        # Refresh known_words if the socket has that assign
        socket =
          if Map.has_key?(socket.assigns, :known_words) do
            scope = socket.assigns.current_scope

            Phoenix.Component.assign(
              socket,
              :known_words,
              Langseed.Vocabulary.known_words_with_understanding(scope)
            )
          else
            socket
          end

        {:noreply, socket}
      end
    end
  end
end

defmodule LangseedWeb.TextAnalysisComponents do
  @moduledoc """
  UI components for the TextAnalysis LiveView.
  """

  use Phoenix.Component

  import LangseedWeb.SharedComponents, only: [understanding_color: 1]

  alias Langseed.HSK

  @doc """
  Renders a text segment (word, punctuation, space, or newline) with appropriate styling.

  Known words are colored by understanding level and clickable.
  Unknown words can be selected for adding to vocabulary.
  """
  attr :segment, :any, required: true
  attr :known_words, :map, required: true
  attr :selected_words, :any, required: true
  attr :show_hsk, :boolean, default: false

  def segment_inline(%{segment: {:newline, _}} = assigns) do
    ~H"<br />"
  end

  def segment_inline(%{segment: {:space, text}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H"<span>{@text}</span>"
  end

  def segment_inline(%{segment: {:punct, text}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H'<span class="opacity-60">{@text}</span>'
  end

  def segment_inline(%{segment: {:word, word}} = assigns) do
    understanding = Map.get(assigns.known_words, word)
    known = understanding != nil
    selected = MapSet.member?(assigns.selected_words, word)
    hsk_level = if assigns.show_hsk, do: HSK.lookup(word), else: nil

    assigns =
      assign(assigns,
        word: word,
        known: known,
        selected: selected,
        understanding: understanding,
        hsk_level: hsk_level
      )

    ~H"""
    <%= if @known do %>
      <ruby
        class="cursor-pointer hover:underline"
        style={"color: #{understanding_color(@understanding)}"}
        phx-click="show_concept"
        phx-value-word={@word}
      >
        {@word}<rt class="text-[10px] opacity-40 font-normal">{@hsk_level}</rt>
      </ruby>
    <% else %>
      <ruby
        class={"cursor-pointer transition-colors #{if @selected, do: "text-primary font-bold underline decoration-2", else: "text-base-content hover:text-primary"}"}
        phx-click="toggle_word"
        phx-value-word={@word}
      >
        {@word}<rt class="text-[10px] opacity-40 font-normal">{@hsk_level}</rt>
      </ruby>
    <% end %>
    """
  end
end

defmodule LangseedWeb.SharedComponents do
  @moduledoc """
  Shared UI components used across multiple LiveViews.
  """

  use Phoenix.Component
  use Gettext, backend: LangseedWeb.Gettext

  import LangseedWeb.CoreComponents, only: [icon: 1]

  alias Langseed.HSK
  alias Langseed.TimeFormatter
  alias Langseed.Practice.ConceptSRS

  @doc """
  Renders a speak button that triggers text-to-speech.
  """
  attr :text, :string, required: true

  def speak_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-hook="Speak"
      id={"speak-#{:erlang.phash2(@text)}"}
      data-text={@text}
      class="btn btn-ghost btn-circle btn-sm"
      title={gettext("Play pronunciation")}
    >
      <.icon name="hero-speaker-wave" class="size-5" />
    </button>
    """
  end

  @doc """
  Renders a star rating for explanation quality (1-5).
  """
  attr :quality, :integer, required: true

  def quality_stars(assigns) do
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

  @doc """
  Calculates the understanding level color (red -> yellow -> green gradient).
  """
  @spec understanding_color(integer()) :: String.t()
  def understanding_color(level) do
    if level < 50 do
      # Red to yellow
      ratio = level / 50
      r = 239
      g = round(68 + (171 - 68) * ratio)
      b = round(68 + (8 - 68) * ratio)
      "rgb(#{r}, #{g}, #{b})"
    else
      # Yellow to green
      ratio = (level - 50) / 50
      r = round(234 - (234 - 34) * ratio)
      g = round(179 + (197 - 179) * ratio)
      b = round(8 + (94 - 8) * ratio)
      "rgb(#{r}, #{g}, #{b})"
    end
  end

  @doc """
  Renders a section displaying desired words that can be added to vocabulary.
  Each word is clickable and will trigger an "add_desired_word" event.
  Words that are already known are filtered out.
  """
  attr :words, :list, required: true
  attr :context, :string, default: nil
  attr :importing_words, :list, default: []
  attr :known_words, :any, default: nil

  def desired_words_section(assigns) do
    # Filter out words that are already known
    filtered_words =
      if assigns.known_words do
        Enum.reject(assigns.words, fn word ->
          case assigns.known_words do
            %MapSet{} -> MapSet.member?(assigns.known_words, word)
            %{} -> Map.has_key?(assigns.known_words, word)
            _ -> false
          end
        end)
      else
        assigns.words
      end

    assigns = assign(assigns, :filtered_words, filtered_words)

    ~H"""
    <%= if length(@filtered_words) > 0 do %>
      <div class="mt-3 p-3 bg-info/10 rounded-lg">
        <p class="text-xs opacity-60 mb-2">
          💡 {gettext("Learning these words can improve explanations:")}
        </p>
        <div class="flex flex-wrap gap-1">
          <%= for word <- @filtered_words do %>
            <% is_importing = word in @importing_words %>
            <button
              type="button"
              class={[
                "badge badge-sm transition-colors",
                if(is_importing,
                  do: "badge-info animate-pulse cursor-wait",
                  else:
                    "badge-info badge-outline hover:badge-info hover:text-info-content cursor-pointer"
                )
              ]}
              phx-click={unless is_importing, do: "add_desired_word"}
              phx-value-word={word}
              phx-value-context={@context || ""}
              disabled={is_importing}
              title={
                if is_importing, do: gettext("Adding..."), else: gettext("Click to add to vocabulary")
              }
            >
              <%= if is_importing do %>
                <span class="loading loading-spinner loading-xs mr-1"></span>
              <% else %>
                <span class="mr-1">+</span>
              <% end %>
              {word}
            </button>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a concept card modal.

  ## Options
  - `show_desired_words` - Show desired words section (default: false)
  - `show_example_sentence` - Show example sentence (default: false)
  - `show_understanding_slider` - Show understanding slider (default: false)
  - `show_delete_button` - Show delete button (default: false)
  - `show_srs_progress` - Show SRS progress per question type (default: false)
  """
  attr :concept, :map, required: true
  attr :srs_records, :list, default: []
  attr :show_desired_words, :boolean, default: false
  attr :show_example_sentence, :boolean, default: false
  attr :show_understanding_slider, :boolean, default: false
  attr :show_delete_button, :boolean, default: false
  attr :show_pause_button, :boolean, default: false
  attr :show_srs_progress, :boolean, default: false
  attr :importing_words, :list, default: []
  attr :known_words, :any, default: nil

  def concept_card(assigns) do
    # HSK level only makes sense for Chinese
    hsk_level =
      if assigns.concept.language == "zh", do: HSK.lookup(assigns.concept.word), else: nil

    assigns = assign(assigns, :hsk_level, hsk_level)

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
              <%= if @concept.language == "zh" && @concept.pinyin && @concept.pinyin != "" && @concept.pinyin != "-" do %>
                <p class="text-xl text-primary mt-1">{@concept.pinyin}</p>
              <% end %>
              <div class="flex gap-1">
                <span class="badge badge-sm badge-ghost">{@concept.part_of_speech}</span>
                <%= if @hsk_level do %>
                  <span class="badge badge-sm badge-outline">HSK {@hsk_level}</span>
                <% end %>
              </div>
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
                  <span>{gettext("Explanation quality:")}</span>
                  <.quality_stars quality={@concept.explanation_quality} />
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @show_desired_words && @concept.desired_words && length(@concept.desired_words) > 0 do %>
            <.desired_words_section
              words={@concept.desired_words}
              context={@concept.example_sentence}
              importing_words={@importing_words}
              known_words={@known_words}
            />
          <% end %>

          <%= if @show_example_sentence && @concept.example_sentence do %>
            <p class="text-sm italic opacity-70 mt-2 border-l-2 border-base-300 pl-2">
              {@concept.example_sentence}
            </p>
          <% end %>

          <%= if @show_understanding_slider do %>
            <div class="mt-4">
              <div class="flex items-center gap-2">
                <span class="text-sm opacity-50">{gettext("Understanding")}</span>
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
          <% end %>

          <%= if @show_srs_progress && length(@srs_records) > 0 do %>
            <.srs_progress_display srs_records={@srs_records} />
          <% end %>

          <details class="mt-3">
            <summary class="text-xs opacity-40 cursor-pointer hover:opacity-60">
              👁️ {gettext("English")}
            </summary>
            <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
          </details>

          <%= if @show_delete_button || @show_pause_button do %>
            <div class="card-actions justify-between mt-4">
              <%= if @show_pause_button do %>
                <button
                  class={[
                    "btn btn-sm",
                    if(@concept.paused, do: "btn-success", else: "btn-warning")
                  ]}
                  phx-click="toggle_pause"
                  phx-value-id={@concept.id}
                >
                  <%= if @concept.paused do %>
                    <.icon name="hero-play" class="size-4" /> {gettext("Resume practice")}
                  <% else %>
                    <.icon name="hero-pause" class="size-4" /> {gettext("Pause practice")}
                  <% end %>
                </button>
              <% else %>
                <div></div>
              <% end %>
              <%= if @show_delete_button do %>
                <button
                  class="btn btn-error btn-sm"
                  phx-click="delete"
                  phx-value-id={@concept.id}
                  data-confirm={gettext("Delete %{word}?", word: @concept.word)}
                >
                  <.icon name="hero-trash" class="size-4" /> {gettext("Delete")}
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders SRS progress for each question type.
  Shows the tier (as a progress bar) and next review time.
  """
  attr :srs_records, :list, required: true

  def srs_progress_display(assigns) do
    ~H"""
    <div class="mt-4 p-3 bg-base-200 rounded-lg">
      <p class="text-xs opacity-60 mb-2">{gettext("Practice Progress")}</p>
      <div class="space-y-2">
        <%= for srs <- @srs_records do %>
          <.srs_type_row srs={srs} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :srs, :map, required: true

  defp srs_type_row(assigns) do
    tier = assigns.srs.tier
    percent = ConceptSRS.tier_to_percent(tier)
    next_review = TimeFormatter.format_relative(assigns.srs.next_review)
    question_type = Langseed.Practice.ConceptSRS.format_question_type(assigns.srs.question_type)

    is_due =
      assigns.srs.next_review &&
        DateTime.compare(assigns.srs.next_review, DateTime.utc_now()) != :gt

    is_graduated = tier >= 7

    assigns =
      assigns
      |> assign(:percent, percent)
      |> assign(:next_review, next_review)
      |> assign(:question_type, question_type)
      |> assign(:is_due, is_due)
      |> assign(:is_graduated, is_graduated)

    ~H"""
    <div class="flex items-center gap-2">
      <span class="text-xs w-24 shrink-0">{@question_type}</span>
      <div class="flex-1 h-2 bg-base-300 rounded-full overflow-hidden">
        <div
          class={[
            "h-full rounded-full transition-all",
            cond do
              @is_graduated -> "bg-success"
              @percent >= 50 -> "bg-warning"
              true -> "bg-error"
            end
          ]}
          style={"width: #{@percent}%"}
        />
      </div>
      <span class={[
        "text-xs w-20 shrink-0",
        @is_due && "text-error font-medium",
        @is_graduated && "text-success"
      ]}>
        {@next_review}
      </span>
    </div>
    """
  end
end

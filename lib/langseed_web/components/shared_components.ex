defmodule LangseedWeb.SharedComponents do
  @moduledoc """
  Shared UI components used across multiple LiveViews.
  """

  use Phoenix.Component

  import LangseedWeb.CoreComponents, only: [icon: 1]

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
      title="播放发音"
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
  """
  attr :words, :list, required: true
  attr :context, :string, default: nil
  attr :importing_words, :list, default: []

  def desired_words_section(assigns) do
    ~H"""
    <div class="mt-3 p-3 bg-info/10 rounded-lg">
      <p class="text-xs opacity-60 mb-2">💡 学这些词可以改进解释:</p>
      <div class="flex flex-wrap gap-1">
        <%= for word <- @words do %>
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
            title={if is_importing, do: "添加中...", else: "点击添加到词汇"}
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
    """
  end

  @doc """
  Renders a concept card modal.

  ## Options
  - `show_desired_words` - Show desired words section (default: false)
  - `show_example_sentence` - Show example sentence (default: false)
  - `show_understanding_slider` - Show understanding slider (default: false)
  - `show_delete_button` - Show delete button (default: false)
  """
  attr :concept, :map, required: true
  attr :show_desired_words, :boolean, default: false
  attr :show_example_sentence, :boolean, default: false
  attr :show_understanding_slider, :boolean, default: false
  attr :show_delete_button, :boolean, default: false
  attr :show_pause_button, :boolean, default: false
  attr :importing_words, :list, default: []

  def concept_card(assigns) do
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

          <%= if @show_desired_words && @concept.desired_words && length(@concept.desired_words) > 0 do %>
            <.desired_words_section
              words={@concept.desired_words}
              context={@concept.example_sentence}
              importing_words={@importing_words}
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
          <% end %>

          <details class="mt-3">
            <summary class="text-xs opacity-40 cursor-pointer hover:opacity-60">
              👁️ 英文
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
                    <.icon name="hero-play" class="size-4" /> 恢复练习
                  <% else %>
                    <.icon name="hero-pause" class="size-4" /> 暂停练习
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
                  data-confirm={"删除 #{@concept.word}?"}
                >
                  <.icon name="hero-trash" class="size-4" /> 删除
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

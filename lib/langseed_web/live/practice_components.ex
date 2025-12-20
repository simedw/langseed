defmodule LangseedWeb.PracticeComponents do
  @moduledoc """
  UI components for the Practice LiveView.
  """

  use Phoenix.Component
  use Gettext, backend: LangseedWeb.Gettext

  import LangseedWeb.CoreComponents, only: [icon: 1]
  import LangseedWeb.SharedComponents, only: [speak_button: 1, desired_words_section: 1]

  @doc """
  Renders a card shown when there are no words to practice.
  """
  def no_words_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body text-center">
        <div class="text-6xl mb-4">🎉</div>
        <h2 class="card-title justify-center">{gettext("Well done!")}</h2>
        <p class="opacity-70">{gettext("No words need practice")}</p>
        <p class="text-sm opacity-50 mt-2">
          {gettext("Go to %{link} to add more words",
            link: ~s(<a href="/analyze" class="link link-primary">#{gettext("Analyze")}</a>)
          )
          |> Phoenix.HTML.raw()}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading card with an optional message.
  """
  attr :message, :string, default: nil

  def loading_card(assigns) do
    assigns =
      assign_new(assigns, :display_message, fn -> assigns.message || gettext("Loading...") end)

    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center">
        <span class="loading loading-spinner loading-lg"></span>
        <p class="opacity-70 mt-4">{@display_message}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a card for learning a new word definition.
  """
  attr :concept, :map, required: true
  attr :loading, :boolean, default: false
  attr :importing_words, :list, default: []

  def definition_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <div class="flex justify-end -mt-2 -mr-2 mb-2">
          <button
            class="btn btn-ghost btn-xs opacity-50 hover:opacity-100"
            phx-click="pause_word"
            title={gettext("Pause this word")}
          >
            <.icon name="hero-pause" class="size-4" /> {gettext("Pause")}
          </button>
        </div>
        <div class="text-center mb-4">
          <span class="badge badge-warning mb-2">{gettext("New word")}</span>
          <div class="flex items-center justify-center gap-2">
            <h2 class="text-5xl font-bold">{@concept.word}</h2>
            <.speak_button text={@concept.word} />
          </div>
          <%= if @concept.language == "zh" && @concept.pinyin && @concept.pinyin != "" && @concept.pinyin != "-" do %>
            <p class="text-xl text-primary mt-2">{@concept.pinyin}</p>
          <% end %>
        </div>

        <div class="bg-base-300 rounded-lg p-4 mb-4">
          <div class="space-y-2">
            <%= for explanation <- (@concept.explanations || []) do %>
              <p class="text-xl text-center">{explanation}</p>
            <% end %>
            <%= if Enum.empty?(@concept.explanations || []) do %>
              <p class="text-2xl text-center">🤔</p>
            <% end %>
          </div>
        </div>

        <%= if @concept.desired_words && length(@concept.desired_words) > 0 do %>
          <.desired_words_section
            words={@concept.desired_words}
            context={@concept.example_sentence}
            importing_words={@importing_words}
          />
        <% end %>

        <details class="mb-4">
          <summary class="text-xs opacity-40 cursor-pointer hover:opacity-60">
            👁️ {gettext("English")}
          </summary>
          <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
        </details>

        <div class="flex flex-col gap-2">
          <button class="btn btn-success" phx-click="understand" disabled={@loading}>
            <.icon name="hero-check" class="size-5" /> {gettext("I understand")}
          </button>
          <button class="btn btn-outline" phx-click="new_explanation" disabled={@loading}>
            <%= if @loading do %>
              <span class="loading loading-spinner loading-sm"></span>
            <% else %>
              <.icon name="hero-arrow-path" class="size-5" />
            <% end %>
            {gettext("Try another explanation")}
          </button>
          <button class="btn btn-ghost btn-sm" phx-click="skip" disabled={@loading}>
            {gettext("Skip")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a quiz card with yes/no or fill-in-the-blank questions.
  """
  attr :concept, :map, required: true
  attr :question, :map, required: true
  attr :feedback, :map, default: nil
  attr :user_answer, :any, default: nil

  def quiz_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <div class="flex justify-end -mt-2 -mr-2 mb-2">
          <button
            class="btn btn-ghost btn-xs opacity-50 hover:opacity-100"
            phx-click="pause_word"
            title={gettext("Pause this word")}
          >
            <.icon name="hero-pause" class="size-4" /> {gettext("Pause")}
          </button>
        </div>
        <%= case @question.question_type do %>
          <% "yes_no" -> %>
            <.yes_no_question question={@question} feedback={@feedback} user_answer={@user_answer} />
          <% type when type in ["fill_blank", "multiple_choice"] -> %>
            <.fill_blank_question
              question={@question}
              feedback={@feedback}
              user_answer={@user_answer}
            />
        <% end %>

        <%= if @feedback do %>
          <div class="mt-4">
            <button class="btn btn-primary w-full" phx-click="next">
              {gettext("Next")} <.icon name="hero-arrow-right" class="size-5" />
            </button>
          </div>
        <% else %>
          <div class="mt-4 text-center">
            <button class="btn btn-ghost btn-sm" phx-click="switch_to_sentence">
              {gettext("Write sentence")}
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a yes/no question.
  """
  attr :question, :map, required: true
  attr :feedback, :map, default: nil
  attr :user_answer, :any, default: nil

  def yes_no_question(assigns) do
    ~H"""
    <div class="my-4">
      <div class="flex items-center justify-center gap-2 mb-6">
        <p class="text-xl text-center">{@question.question_text}</p>
        <.speak_button text={@question.question_text} />
      </div>

      <%= if @feedback do %>
        <div class={"alert #{if @feedback.correct, do: "alert-success", else: "alert-error"} mb-4"}>
          <span class="text-2xl">{if @feedback.correct, do: "✅", else: "❌"}</span>
          <div>
            <p class="font-bold">
              {if @feedback.correct, do: gettext("Correct!"), else: gettext("Wrong")}
            </p>
            <%= if @feedback.explanation && @feedback.explanation != "" do %>
              <p class="text-sm">{@feedback.explanation}</p>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="flex gap-4 justify-center">
          <button
            class="btn btn-lg btn-success flex-1"
            phx-click="answer_yes_no"
            phx-value-answer="yes"
          >
            {gettext("Yes")} ✓
          </button>
          <button
            class="btn btn-lg btn-error flex-1"
            phx-click="answer_yes_no"
            phx-value-answer="no"
          >
            {gettext("No")} ✗
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a fill-in-the-blank question with multiple choice options.
  """
  attr :question, :map, required: true
  attr :feedback, :map, default: nil
  attr :user_answer, :any, default: nil

  def fill_blank_question(assigns) do
    ~H"""
    <div class="my-4">
      <div class="flex items-center justify-center gap-2 mb-6">
        <p class="text-xl text-center">{@question.question_text}</p>
        <.speak_button text={String.replace(@question.question_text, "____", "")} />
      </div>

      <div class="grid grid-cols-2 gap-3">
        <%= for {option, index} <- Enum.with_index(@question.options) do %>
          <button
            class={[
              "btn btn-lg",
              cond do
                @feedback && @feedback.correct && @user_answer == index ->
                  "btn-success"

                @feedback && !@feedback.correct && @user_answer == index ->
                  "btn-error"

                @feedback && @question.correct_answer == Integer.to_string(index) ->
                  "btn-success btn-outline"

                @feedback ->
                  "btn-ghost"

                true ->
                  "btn-outline"
              end
            ]}
            phx-click="answer_fill_blank"
            phx-value-index={index}
            disabled={@feedback != nil}
          >
            {option}
          </button>
        <% end %>
      </div>

      <%= if @feedback do %>
        <div class={"alert #{if @feedback.correct, do: "alert-success", else: "alert-error"} mt-4"}>
          <span class="text-2xl">{if @feedback.correct, do: "✅", else: "❌"}</span>
          <p class="font-bold">
            {if @feedback.correct,
              do: gettext("Correct!"),
              else: gettext("Correct answer: %{answer}", answer: @feedback.correct_answer)}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a card for sentence writing practice.
  """
  attr :concept, :map, required: true
  attr :sentence_input, :string, default: ""
  attr :feedback, :map, default: nil
  attr :loading, :boolean, default: false

  def sentence_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <div class="flex justify-end -mt-2 -mr-2 mb-2">
          <button
            class="btn btn-ghost btn-xs opacity-50 hover:opacity-100"
            phx-click="pause_word"
            title={gettext("Pause this word")}
          >
            <.icon name="hero-pause" class="size-4" /> {gettext("Pause")}
          </button>
        </div>
        <div class="text-center mb-4">
          <span class="badge badge-info mb-2">{gettext("Write sentence")}</span>
          <div class="flex items-center justify-center gap-2">
            <h2 class="text-3xl font-bold">{@concept.word}</h2>
            <.speak_button text={@concept.word} />
          </div>
          <%= if @concept.language == "zh" && @concept.pinyin && @concept.pinyin != "" && @concept.pinyin != "-" do %>
            <p class="text-lg text-primary">{@concept.pinyin}</p>
          <% end %>
          <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
        </div>

        <p class="text-center mb-4 opacity-70">
          {gettext("Write a sentence using %{word}",
            word: ~s(<span class="font-bold text-primary">#{@concept.word}</span>)
          )
          |> Phoenix.HTML.raw()}
        </p>

        <%= if @feedback do %>
          <div class={"alert #{if @feedback.correct, do: "alert-success", else: "alert-warning"} mb-4"}>
            <div>
              <p class="font-bold">
                {if @feedback.correct, do: gettext("Good!"), else: gettext("Needs improvement")}
              </p>
              <p>{@feedback.feedback}</p>
              <%= if @feedback.improved do %>
                <p class="text-sm mt-2 opacity-70">{gettext("Suggestion:")} {@feedback.improved}</p>
              <% end %>
            </div>
          </div>

          <button class="btn btn-primary w-full" phx-click="next">
            {gettext("Next")} <.icon name="hero-arrow-right" class="size-5" />
          </button>
        <% else %>
          <form phx-submit="submit_sentence" phx-change="update_sentence">
            <textarea
              class="textarea textarea-bordered w-full h-24 text-lg mb-4"
              placeholder={gettext("Write your sentence...")}
              name="sentence"
              disabled={@loading}
            >{@sentence_input}</textarea>

            <button
              type="submit"
              class="btn btn-primary w-full"
              disabled={@loading || String.trim(@sentence_input) == ""}
            >
              <%= if @loading do %>
                <span class="loading loading-spinner loading-sm"></span> {gettext("Checking...")}
              <% else %>
                <.icon name="hero-paper-airplane" class="size-5" /> {gettext("Submit")}
              <% end %>
            </button>
          </form>

          <button class="btn btn-ghost btn-sm w-full mt-2" phx-click="skip">
            {gettext("Skip")}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a card for pinyin quiz practice.
  User sees the Chinese word and must type the pinyin with tones.
  """
  attr :concept, :map, required: true
  attr :pinyin_input, :string, default: ""
  attr :feedback, :map, default: nil

  def pinyin_quiz_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <div class="flex justify-end -mt-2 -mr-2 mb-2">
          <button
            class="btn btn-ghost btn-xs opacity-50 hover:opacity-100"
            phx-click="pause_word"
            title={gettext("Pause this word")}
          >
            <.icon name="hero-pause" class="size-4" /> {gettext("Pause")}
          </button>
        </div>

        <div class="text-center mb-4">
          <span class="badge badge-secondary mb-2">{gettext("Write pinyin")}</span>
          <h2 class="text-5xl font-bold mb-2">{@concept.word}</h2>
          <p class="text-sm opacity-60">{@concept.meaning}</p>
        </div>

        <p class="text-center text-sm opacity-70 mb-4">
          {gettext("Type the pinyin with tone numbers (e.g., ni3 hao3)")}
        </p>

        <%= if @feedback do %>
          <div class={"alert #{if @feedback.correct, do: "alert-success", else: "alert-error"} mb-4"}>
            <span class="text-2xl">{if @feedback.correct, do: "✅", else: "❌"}</span>
            <div>
              <%= if @feedback.correct do %>
                <p class="font-bold">{gettext("Correct!")}</p>
              <% else %>
                <p class="font-bold">{@feedback.expected_toned}</p>
                <p class="text-sm opacity-70">{@feedback.expected_numbered}</p>
              <% end %>
            </div>
          </div>

          <button class="btn btn-primary w-full" phx-click="next">
            {gettext("Next")} <.icon name="hero-arrow-right" class="size-5" />
          </button>
        <% else %>
          <form phx-submit="submit_pinyin" phx-change="update_pinyin">
            <input
              type="text"
              class="input input-bordered w-full text-xl text-center mb-4"
              placeholder={gettext("e.g., ni3 hao3")}
              name="pinyin"
              value={@pinyin_input}
              autocomplete="off"
              autocapitalize="off"
              spellcheck="false"
            />

            <button
              type="submit"
              class="btn btn-primary w-full"
              disabled={String.trim(@pinyin_input) == ""}
            >
              <.icon name="hero-check" class="size-5" /> {gettext("Check")}
            </button>
          </form>

          <button class="btn btn-ghost btn-sm w-full mt-2" phx-click="skip">
            {gettext("Skip")}
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end

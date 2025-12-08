defmodule LangseedWeb.PracticeComponents do
  @moduledoc """
  UI components for the Practice LiveView.
  """

  use Phoenix.Component

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
        <h2 class="card-title justify-center">做得好！</h2>
        <p class="opacity-70">没有需要练习的词汇了</p>
        <p class="text-sm opacity-50 mt-2">
          去 <a href="/analyze" class="link link-primary">分析</a> 添加更多词汇
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading card with an optional message.
  """
  attr :message, :string, default: "加载中..."

  def loading_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center">
        <span class="loading loading-spinner loading-lg"></span>
        <p class="opacity-70 mt-4">{@message}</p>
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
            title="暂停这个词"
          >
            <.icon name="hero-pause" class="size-4" /> 暂停
          </button>
        </div>
        <div class="text-center mb-4">
          <span class="badge badge-warning mb-2">新词</span>
          <div class="flex items-center justify-center gap-2">
            <h2 class="text-5xl font-bold">{@concept.word}</h2>
            <.speak_button text={@concept.word} />
          </div>
          <p class="text-xl text-primary mt-2">{@concept.pinyin}</p>
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
            👁️ 英文
          </summary>
          <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
        </details>

        <div class="flex flex-col gap-2">
          <button
            class="btn btn-success"
            phx-click="understand"
            disabled={@loading}
          >
            <.icon name="hero-check" class="size-5" /> 我懂了
          </button>
          <button
            class="btn btn-outline"
            phx-click="new_explanation"
            disabled={@loading}
          >
            <%= if @loading do %>
              <span class="loading loading-spinner loading-sm"></span>
            <% else %>
              <.icon name="hero-arrow-path" class="size-5" />
            <% end %>
            换一个解释
          </button>
          <button
            class="btn btn-ghost btn-sm"
            phx-click="skip"
            disabled={@loading}
          >
            跳过
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
            title="暂停这个词"
          >
            <.icon name="hero-pause" class="size-4" /> 暂停
          </button>
        </div>
        <%= case @question.question_type do %>
          <% "yes_no" -> %>
            <.yes_no_question question={@question} feedback={@feedback} user_answer={@user_answer} />
          <% "fill_blank" -> %>
            <.fill_blank_question
              question={@question}
              feedback={@feedback}
              user_answer={@user_answer}
            />
        <% end %>

        <%= if @feedback do %>
          <div class="mt-4">
            <button class="btn btn-primary w-full" phx-click="next">
              下一个 <.icon name="hero-arrow-right" class="size-5" />
            </button>
          </div>
        <% else %>
          <div class="mt-4 text-center">
            <button class="btn btn-ghost btn-sm" phx-click="switch_to_sentence">
              写句子练习
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
            <p class="font-bold">{if @feedback.correct, do: "正确！", else: "错误"}</p>
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
            是 ✓
          </button>
          <button
            class="btn btn-lg btn-error flex-1"
            phx-click="answer_yes_no"
            phx-value-answer="no"
          >
            不是 ✗
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
            {if @feedback.correct, do: "正确！", else: "正确答案: #{@feedback.correct_answer}"}
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
            title="暂停这个词"
          >
            <.icon name="hero-pause" class="size-4" /> 暂停
          </button>
        </div>
        <div class="text-center mb-4">
          <span class="badge badge-info mb-2">写句子</span>
          <div class="flex items-center justify-center gap-2">
            <h2 class="text-3xl font-bold">{@concept.word}</h2>
            <.speak_button text={@concept.word} />
          </div>
          <p class="text-lg text-primary">{@concept.pinyin}</p>
          <p class="text-sm opacity-60 mt-1">{@concept.meaning}</p>
        </div>

        <p class="text-center mb-4 opacity-70">
          用 <span class="font-bold text-primary">{@concept.word}</span> 写一个句子
        </p>

        <%= if @feedback do %>
          <div class={"alert #{if @feedback.correct, do: "alert-success", else: "alert-warning"} mb-4"}>
            <div>
              <p class="font-bold">{if @feedback.correct, do: "很好！👍", else: "需要改进"}</p>
              <p>{@feedback.feedback}</p>
              <%= if @feedback.improved do %>
                <p class="text-sm mt-2 opacity-70">建议: {@feedback.improved}</p>
              <% end %>
            </div>
          </div>

          <button class="btn btn-primary w-full" phx-click="next">
            下一个 <.icon name="hero-arrow-right" class="size-5" />
          </button>
        <% else %>
          <form phx-submit="submit_sentence" phx-change="update_sentence">
            <textarea
              class="textarea textarea-bordered w-full h-24 text-lg mb-4"
              placeholder="写你的句子..."
              name="sentence"
              disabled={@loading}
            >{@sentence_input}</textarea>

            <button
              type="submit"
              class="btn btn-primary w-full"
              disabled={@loading || String.trim(@sentence_input) == ""}
            >
              <%= if @loading do %>
                <span class="loading loading-spinner loading-sm"></span> 检查中...
              <% else %>
                <.icon name="hero-paper-airplane" class="size-5" /> 提交
              <% end %>
            </button>
          </form>

          <button class="btn btn-ghost btn-sm w-full mt-2" phx-click="skip">
            跳过
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end

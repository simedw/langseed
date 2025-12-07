defmodule LangseedWeb.PracticeLive do
  use LangseedWeb, :live_view

  alias Langseed.Practice

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Practice",
       current_concept: nil,
       mode: :loading,
       question: nil,
       user_answer: nil,
       feedback: nil,
       sentence_input: "",
       loading: false
     )
     |> load_next_concept()}
  end

  defp get_current_user(socket) do
    case socket.assigns[:current_scope] do
      %{user: user} -> user
      _ -> nil
    end
  end

  defp load_next_concept(socket) do
    user = get_current_user(socket)

    case Practice.get_next_concept(user) do
      nil ->
        assign(socket, mode: :no_words, current_concept: nil)

      concept ->
        mode = if concept.understanding == 0, do: :definition, else: :loading_quiz

        socket =
          assign(socket,
            current_concept: concept,
            mode: mode,
            question: nil,
            feedback: nil,
            user_answer: nil
          )

        if mode == :loading_quiz do
          socket
          |> assign(loading: true)
          |> start_async(:generate_question, fn ->
            Practice.get_or_generate_question(user, concept)
          end)
        else
          socket
        end
    end
  end

  @impl true
  def handle_async(:generate_question, {:ok, {:ok, question}}, socket) do
    {:noreply, assign(socket, question: question, mode: :quiz, loading: false)}
  end

  @impl true
  def handle_async(:generate_question, {:ok, {:error, _reason}}, socket) do
    # Fallback to sentence writing if question generation fails
    {:noreply, assign(socket, mode: :sentence_writing, loading: false)}
  end

  @impl true
  def handle_async(:generate_question, {:exit, _reason}, socket) do
    {:noreply, assign(socket, mode: :sentence_writing, loading: false)}
  end

  @impl true
  def handle_async(:regenerate_explanation, {:ok, {:ok, updated_concept}}, socket) do
    {:noreply,
     socket
     |> assign(current_concept: updated_concept, loading: false)
     |> put_flash(:info, "新解释已生成")}
  end

  @impl true
  def handle_async(:regenerate_explanation, {:ok, {:error, _}}, socket) do
    {:noreply,
     socket
     |> assign(loading: false)
     |> put_flash(:error, "生成失败，请再试")}
  end

  @impl true
  def handle_async(:regenerate_explanation, {:exit, _}, socket) do
    {:noreply, assign(socket, loading: false) |> put_flash(:error, "生成失败")}
  end

  @impl true
  def handle_async(:evaluate_sentence, {:ok, {:ok, result}}, socket) do
    concept = socket.assigns.current_concept

    # Update understanding based on result
    if result.correct do
      Practice.record_answer(concept, true)
    else
      Practice.record_answer(concept, false)
    end

    {:noreply, assign(socket, feedback: result, loading: false)}
  end

  @impl true
  def handle_async(:evaluate_sentence, {:ok, {:error, _}}, socket) do
    {:noreply, assign(socket, loading: false) |> put_flash(:error, "评估失败")}
  end

  @impl true
  def handle_async(:evaluate_sentence, {:exit, _}, socket) do
    {:noreply, assign(socket, loading: false) |> put_flash(:error, "评估失败")}
  end

  # Definition mode handlers
  @impl true
  def handle_event("understand", _, socket) do
    concept = socket.assigns.current_concept
    Practice.mark_understood(concept)

    {:noreply, load_next_concept(socket)}
  end

  @impl true
  def handle_event("new_explanation", _, socket) do
    user = get_current_user(socket)
    concept = socket.assigns.current_concept

    {:noreply,
     socket
     |> assign(loading: true)
     |> start_async(:regenerate_explanation, fn ->
       Practice.regenerate_explanation(user, concept)
     end)}
  end

  @impl true
  def handle_event("skip", _, socket) do
    {:noreply, load_next_concept(socket)}
  end

  # Quiz mode handlers
  @impl true
  def handle_event("answer_yes_no", %{"answer" => answer}, socket) do
    question = socket.assigns.question
    concept = socket.assigns.current_concept
    correct = question.correct_answer == answer

    Practice.mark_question_used(question)
    Practice.record_answer(concept, correct)

    feedback = %{
      correct: correct,
      explanation: question.explanation || "",
      correct_answer: question.correct_answer
    }

    {:noreply, assign(socket, feedback: feedback, user_answer: answer)}
  end

  @impl true
  def handle_event("answer_fill_blank", %{"index" => index_str}, socket) do
    question = socket.assigns.question
    concept = socket.assigns.current_concept
    index = String.to_integer(index_str)
    correct = question.correct_answer == index_str

    Practice.mark_question_used(question)
    Practice.record_answer(concept, correct)

    correct_word = Enum.at(question.options, String.to_integer(question.correct_answer))

    feedback = %{
      correct: correct,
      correct_answer: correct_word,
      selected_index: index
    }

    {:noreply, assign(socket, feedback: feedback, user_answer: index)}
  end

  @impl true
  def handle_event("update_sentence", %{"sentence" => sentence}, socket) do
    {:noreply, assign(socket, sentence_input: sentence)}
  end

  @impl true
  def handle_event("submit_sentence", _, socket) do
    user = get_current_user(socket)
    sentence = socket.assigns.sentence_input
    concept = socket.assigns.current_concept

    if String.trim(sentence) == "" do
      {:noreply, put_flash(socket, :error, "请写一个句子")}
    else
      {:noreply,
       socket
       |> assign(loading: true)
       |> start_async(:evaluate_sentence, fn ->
         Practice.evaluate_sentence(user, concept, sentence)
       end)}
    end
  end

  @impl true
  def handle_event("next", _, socket) do
    {:noreply,
     socket
     |> assign(sentence_input: "", feedback: nil, user_answer: nil)
     |> load_next_concept()}
  end

  @impl true
  def handle_event("switch_to_sentence", _, socket) do
    {:noreply, assign(socket, mode: :sentence_writing)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4 max-w-lg mx-auto">
        <h1 class="text-2xl font-bold mb-6 text-center">练习</h1>

        <%= case @mode do %>
          <% :no_words -> %>
            <.no_words_card />
          <% :loading -> %>
            <.loading_card />
          <% :loading_quiz -> %>
            <.loading_card message="生成问题中..." />
          <% :definition -> %>
            <.definition_card concept={@current_concept} loading={@loading} />
          <% :quiz -> %>
            <.quiz_card
              concept={@current_concept}
              question={@question}
              feedback={@feedback}
              user_answer={@user_answer}
            />
          <% :sentence_writing -> %>
            <.sentence_card
              concept={@current_concept}
              sentence_input={@sentence_input}
              feedback={@feedback}
              loading={@loading}
            />
        <% end %>
      </div>
    </div>
    """
  end

  defp no_words_card(assigns) do
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

  defp loading_card(assigns) do
    assigns = assign_new(assigns, :message, fn -> "加载中..." end)

    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body items-center text-center">
        <span class="loading loading-spinner loading-lg"></span>
        <p class="opacity-70 mt-4">{@message}</p>
      </div>
    </div>
    """
  end

  defp definition_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
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

  defp quiz_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
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

  defp yes_no_question(assigns) do
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

  defp fill_blank_question(assigns) do
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

  defp sentence_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
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

  defp speak_button(assigns) do
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
end

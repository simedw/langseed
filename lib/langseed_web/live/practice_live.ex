defmodule LangseedWeb.PracticeLive do
  use LangseedWeb, :live_view

  import LangseedWeb.PracticeComponents

  alias Langseed.Practice
  alias Langseed.Vocabulary
  alias Langseed.Services.WordImporter

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
       loading: false,
       importing_words: []
     )
     |> load_next_concept()}
  end

  defp load_next_concept(socket) do
    user = current_user(socket)

    case Practice.get_next_concept(user) do
      nil -> assign(socket, mode: :no_words, current_concept: nil)
      concept -> setup_concept(socket, user, concept)
    end
  end

  defp setup_concept(socket, user, concept) do
    mode = if concept.understanding == 0, do: :definition, else: :loading_quiz

    socket
    |> assign(
      current_concept: concept,
      mode: mode,
      question: nil,
      feedback: nil,
      user_answer: nil
    )
    |> maybe_start_quiz_generation(user, concept, mode)
  end

  defp maybe_start_quiz_generation(socket, user, concept, :loading_quiz) do
    socket
    |> assign(loading: true)
    |> start_async(:generate_question, fn -> Practice.get_or_generate_question(user, concept) end)
  end

  defp maybe_start_quiz_generation(socket, _user, _concept, _mode), do: socket

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

  @impl true
  def handle_async({:import_word, word}, {:ok, {[_], []}}, socket) do
    {:noreply,
     socket
     |> put_flash(:success, "添加了 #{word} ✓")
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[], [_]}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "添加 #{word} 失败")
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def handle_async({:import_word, word}, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "添加 #{word} 失败")
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  # Pause word handler
  @impl true
  def handle_event("pause_word", _, socket) do
    concept = socket.assigns.current_concept
    {:ok, _} = Vocabulary.pause_concept(concept)

    {:noreply,
     socket
     |> put_flash(:info, "暂停了 #{concept.word}")
     |> load_next_concept()}
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
    user = current_user(socket)
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
    user = current_user(socket)
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

  # Desired word handlers
  @impl true
  def handle_event("add_desired_word", %{"word" => word, "context" => context}, socket) do
    user = current_user(socket)

    # Check if word already exists
    if Vocabulary.word_known?(user, word) do
      {:noreply, put_flash(socket, :info, "#{word} 已经在你的词汇表里了")}
    else
      {:noreply,
       socket
       |> assign(importing_words: [word | socket.assigns.importing_words])
       |> start_async({:import_word, word}, fn ->
         WordImporter.import_words(user, [word], context)
       end)}
    end
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
            <.definition_card
              concept={@current_concept}
              loading={@loading}
              importing_words={@importing_words}
            />
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
end

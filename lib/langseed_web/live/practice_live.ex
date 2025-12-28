defmodule LangseedWeb.PracticeLive do
  use LangseedWeb, :live_view
  use LangseedWeb.AudioHelpers

  import LangseedWeb.PracticeComponents

  alias Langseed.Practice
  alias Langseed.Vocabulary
  alias Langseed.Services.WordImporter
  alias Langseed.Language.Pinyin

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Practice"),
       current_concept: nil,
       current_srs: nil,
       mode: :loading,
       question: nil,
       user_answer: nil,
       feedback: nil,
       sentence_input: "",
       pinyin_input: "",
       loading: false,
       importing_words: [],
       session_new_count: 0,
       last_concept_id: nil,
       # Audio features
       audio_available: Langseed.Audio.available?(),
       audio_url: nil,
       audio_loading: false,
       # Synced from client localStorage - defaults to true until synced
       audio_autoplay: true
     )
     |> load_next_practice()}
  end

  # ============================================================================
  # SRS-BASED PRACTICE FLOW
  # ============================================================================

  defp load_next_practice(socket) do
    scope = current_scope(socket)
    last_concept_id = socket.assigns.last_concept_id
    session_new_count = socket.assigns.session_new_count

    result =
      case Practice.get_next_practice(scope,
             last_concept_id: last_concept_id,
             session_new_count: session_new_count
           ) do
        nil ->
          assign(socket, mode: :no_words, current_concept: nil, current_srs: nil)

        {:definition, concept} ->
          setup_definition_mode(socket, concept)

        {:srs, srs_record} ->
          setup_srs_practice(socket, scope, srs_record)
      end

    # Update practice_ready indicator in layout
    practice_ready = Practice.has_practice_ready?(scope)
    assign(result, :practice_ready, practice_ready)
  end

  defp setup_definition_mode(socket, concept) do
    socket
    |> assign(
      current_concept: concept,
      current_srs: nil,
      mode: :definition,
      question: nil,
      feedback: nil,
      user_answer: nil,
      pinyin_input: ""
    )
  end

  defp setup_srs_practice(socket, scope, srs_record) do
    concept = srs_record.concept

    case srs_record.question_type do
      "pinyin" ->
        setup_pinyin_mode(socket, concept, srs_record)

      question_type when question_type in ["yes_no", "multiple_choice"] ->
        setup_quiz_mode(socket, scope, concept, srs_record, question_type)

      _ ->
        # Unknown question type, skip
        load_next_practice(socket)
    end
  end

  defp setup_pinyin_mode(socket, concept, srs_record) do
    socket
    |> assign(
      current_concept: concept,
      current_srs: srs_record,
      mode: :pinyin_quiz,
      question: nil,
      feedback: nil,
      user_answer: nil,
      pinyin_input: ""
    )
  end

  defp setup_quiz_mode(socket, scope, concept, srs_record, question_type) do
    # Try to get a pre-generated question
    case Practice.get_unused_question(concept.id, question_type) do
      nil ->
        start_question_generation(socket, scope, concept, srs_record, question_type)

      question ->
        assign_quiz_question(socket, concept, srs_record, question)
    end
  end

  defp start_question_generation(socket, scope, concept, srs_record, question_type) do
    socket
    |> assign(
      current_concept: concept,
      current_srs: srs_record,
      mode: :loading_quiz,
      loading: true
    )
    |> start_async(:generate_question, fn ->
      generate_question_with_timeout(scope, concept, question_type)
    end)
  end

  defp assign_quiz_question(socket, concept, srs_record, question) do
    socket
    |> assign(
      current_concept: concept,
      current_srs: srs_record,
      mode: :quiz,
      question: question,
      feedback: nil,
      user_answer: nil
    )
  end

  defp generate_question_with_timeout(scope, concept, question_type) do
    # 30 second timeout for LLM call
    task = Task.async(fn -> Practice.generate_question(scope, concept, question_type) end)

    case Task.yield(task, 30_000) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, "Question generation timed out"}
    end
  end

  # ============================================================================
  # ASYNC HANDLERS
  # ============================================================================

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
     |> put_flash(:info, gettext("New explanation generated"))}
  end

  @impl true
  def handle_async(:regenerate_explanation, {:ok, {:error, _}}, socket) do
    {:noreply,
     socket
     |> assign(loading: false)
     |> put_flash(:error, gettext("Generation failed, please try again"))}
  end

  @impl true
  def handle_async(:regenerate_explanation, {:exit, _}, socket) do
    {:noreply, assign(socket, loading: false) |> put_flash(:error, gettext("Generation failed"))}
  end

  @impl true
  def handle_async(:evaluate_sentence, {:ok, {:ok, result}}, socket) do
    srs_record = socket.assigns.current_srs
    concept = socket.assigns.current_concept

    # Record SRS answer if we have an SRS record
    result_recorded =
      if srs_record do
        case Practice.record_srs_answer(srs_record, result.correct) do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            Logger.error(
              "Failed to record SRS answer for concept #{concept.id}: #{inspect(changeset)}"
            )

            :error
        end
      else
        # Legacy fallback
        case Practice.record_answer(concept, result.correct) do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
      end

    socket =
      case result_recorded do
        :ok -> socket
        :error -> put_flash(socket, :warning, gettext("Answer recorded but progress not saved"))
      end

    {:noreply, assign(socket, feedback: result, loading: false)}
  end

  @impl true
  def handle_async(:evaluate_sentence, {:ok, {:error, _}}, socket) do
    {:noreply, assign(socket, loading: false) |> put_flash(:error, gettext("Evaluation failed"))}
  end

  @impl true
  def handle_async(:evaluate_sentence, {:exit, _}, socket) do
    {:noreply, assign(socket, loading: false) |> put_flash(:error, gettext("Evaluation failed"))}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[_], []}}, socket) do
    {:noreply,
     socket
     |> put_flash(:success, gettext("Added %{word}", word: word))
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def handle_async({:import_word, word}, {:ok, {[], [_]}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("Failed to add %{word}", word: word))
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  @impl true
  def handle_async({:import_word, word}, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("Failed to add %{word}", word: word))
     |> assign(importing_words: List.delete(socket.assigns.importing_words, word))}
  end

  # Audio generation async handlers
  @impl true
  def handle_async(:generate_audio, {:ok, {:ok, audio_url}}, socket)
      when not is_nil(audio_url) do
    {:noreply,
     socket
     |> assign(audio_url: audio_url, audio_loading: false)
     |> push_event("play-audio", %{url: audio_url})}
  end

  @impl true
  def handle_async(:generate_audio, {:ok, {:ok, nil}}, socket) do
    # No audio available (language not supported or TTS disabled)
    {:noreply, assign(socket, audio_loading: false)}
  end

  @impl true
  def handle_async(:generate_audio, {:ok, {:error, _reason}}, socket) do
    # Audio generation failed, fail silently
    {:noreply, assign(socket, audio_loading: false)}
  end

  @impl true
  def handle_async(:generate_audio, {:exit, _reason}, socket) do
    # Audio generation crashed, fail silently
    {:noreply, assign(socket, audio_loading: false)}
  end

  @impl true
  def handle_async(:generate_audio, result, socket) do
    # Catch-all for debugging unexpected results
    Logger.warning("Unexpected audio async result: #{inspect(result)}")
    {:noreply, assign(socket, audio_loading: false)}
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  # Pause word handler
  @impl true
  def handle_event("pause_word", _, socket) do
    concept = socket.assigns.current_concept
    {:ok, _} = Vocabulary.pause_concept(concept)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Paused %{word}", word: concept.word))
     |> load_next_practice()}
  end

  # Definition mode handlers
  @impl true
  def handle_event("understand", _, socket) do
    scope = current_scope(socket)
    concept = socket.assigns.current_concept

    # Initialize SRS records for this concept
    # Handle gracefully if concept was deleted
    try do
      Practice.initialize_srs_for_concept(concept, scope.user.id)

      {:noreply,
       socket
       |> assign(
         session_new_count: socket.assigns.session_new_count + 1,
         last_concept_id: concept.id
       )
       |> load_next_practice()}
    rescue
      Ecto.InvalidChangesetError ->
        # Concept was likely deleted, just load next practice
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word no longer available"))
         |> load_next_practice()}
    end
  end

  @impl true
  def handle_event("new_explanation", _, socket) do
    scope = current_scope(socket)
    concept = socket.assigns.current_concept

    {:noreply,
     socket
     |> assign(loading: true)
     |> start_async(:regenerate_explanation, fn ->
       Practice.regenerate_explanation(scope, concept)
     end)}
  end

  @impl true
  def handle_event("skip", _, socket) do
    {:noreply, load_next_practice(socket)}
  end

  # Quiz mode handlers - Yes/No questions
  @impl true
  def handle_event("answer_yes_no", %{"answer" => answer}, socket) do
    question = socket.assigns.question
    srs_record = socket.assigns.current_srs
    correct = question.correct_answer == answer

    Practice.mark_question_used(question)

    # Record SRS answer
    socket =
      if srs_record do
        case Practice.record_srs_answer(srs_record, correct) do
          {:ok, _} ->
            socket

          {:error, changeset} ->
            Logger.error("Failed to record SRS answer: #{inspect(changeset)}")
            put_flash(socket, :warning, gettext("Progress not saved"))
        end
      else
        socket
      end

    feedback = %{
      correct: correct,
      explanation: question.explanation || "",
      correct_answer: question.correct_answer
    }

    # Generate audio for the question (yes/no questions read the question aloud)
    socket =
      socket
      |> assign(
        feedback: feedback,
        user_answer: answer,
        last_concept_id: socket.assigns.current_concept.id,
        audio_url: nil,
        audio_loading: socket.assigns.audio_available && socket.assigns.audio_autoplay
      )
      |> maybe_generate_audio_for_question(question)

    {:noreply, socket}
  end

  # Quiz mode handlers - Multiple Choice questions (formerly fill_blank)
  @impl true
  def handle_event("answer_fill_blank", %{"index" => index_str}, socket) do
    question = socket.assigns.question
    srs_record = socket.assigns.current_srs
    index = String.to_integer(index_str)
    correct = question.correct_answer == index_str

    Practice.mark_question_used(question)

    # Record SRS answer
    socket =
      if srs_record do
        case Practice.record_srs_answer(srs_record, correct) do
          {:ok, _} ->
            socket

          {:error, changeset} ->
            Logger.error("Failed to record SRS answer: #{inspect(changeset)}")
            put_flash(socket, :warning, gettext("Progress not saved"))
        end
      else
        socket
      end

    correct_word = Enum.at(question.options, String.to_integer(question.correct_answer))

    feedback = %{
      correct: correct,
      correct_answer: correct_word,
      selected_index: index
    }

    # Generate audio for the full sentence with the correct answer
    socket =
      socket
      |> assign(
        feedback: feedback,
        user_answer: index,
        last_concept_id: socket.assigns.current_concept.id,
        audio_url: nil,
        audio_loading: socket.assigns.audio_available && socket.assigns.audio_autoplay
      )
      |> maybe_generate_audio_for_question(question)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_sentence", %{"sentence" => sentence}, socket) do
    {:noreply, assign(socket, sentence_input: sentence)}
  end

  # Pinyin quiz handlers
  @impl true
  def handle_event("update_pinyin", %{"pinyin" => pinyin}, socket) do
    {:noreply, assign(socket, pinyin_input: pinyin)}
  end

  @impl true
  def handle_event("submit_pinyin", _, socket) do
    input = socket.assigns.pinyin_input
    concept = socket.assigns.current_concept
    srs_record = socket.assigns.current_srs
    expected = concept.pinyin

    correct = Pinyin.match?(input, expected)

    # Record SRS answer
    socket =
      if srs_record do
        case Practice.record_srs_answer(srs_record, correct) do
          {:ok, _} ->
            socket

          {:error, changeset} ->
            Logger.error("Failed to record SRS answer: #{inspect(changeset)}")
            put_flash(socket, :warning, gettext("Progress not saved"))
        end
      else
        socket
      end

    feedback = %{
      correct: correct,
      expected_numbered: Pinyin.to_numbered(expected),
      expected_toned: expected,
      user_input: Pinyin.normalize(input)
    }

    {:noreply,
     socket
     |> assign(feedback: feedback, user_answer: input, last_concept_id: concept.id)}
  end

  @impl true
  def handle_event("submit_sentence", _, socket) do
    scope = current_scope(socket)
    sentence = socket.assigns.sentence_input
    concept = socket.assigns.current_concept

    if String.trim(sentence) == "" do
      {:noreply, put_flash(socket, :error, "Please write a sentence")}
    else
      {:noreply,
       socket
       |> assign(loading: true)
       |> start_async(:evaluate_sentence, fn ->
         Practice.evaluate_sentence(scope, concept, sentence)
       end)}
    end
  end

  @impl true
  def handle_event("next", _, socket) do
    {:noreply,
     socket
     |> assign(sentence_input: "", feedback: nil, user_answer: nil, audio_url: nil)
     |> load_next_practice()}
  end

  # Audio replay handler
  @impl true
  def handle_event("replay-audio", _, socket) do
    if socket.assigns[:audio_url] do
      {:noreply, push_event(socket, "play-audio", %{url: socket.assigns.audio_url})}
    else
      {:noreply, socket}
    end
  end

  # Manual audio generation (when autoplay is off but user clicks speaker)
  @impl true
  def handle_event("generate-audio", _, socket) do
    question = socket.assigns.question

    if socket.assigns.audio_available && question do
      socket =
        socket
        |> assign(audio_loading: true)
        |> generate_audio_for_question(question)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Audio autoplay preference sync from client localStorage
  @impl true
  def handle_event("audio_autoplay_changed", %{"enabled" => enabled}, socket) do
    {:noreply, assign(socket, audio_autoplay: enabled)}
  end

  @impl true
  def handle_event("switch_to_sentence", _, socket) do
    {:noreply, assign(socket, mode: :sentence_writing)}
  end

  # Desired word handlers
  # Desired word handlers
  @impl true
  def handle_event("add_desired_word", %{"word" => word, "context" => context}, socket) do
    scope = current_scope(socket)

    # Check if word already exists
    if Vocabulary.word_known?(scope, word) do
      {:noreply, put_flash(socket, :info, "#{word} is already in your vocabulary")}
    else
      {:noreply,
       socket
       |> assign(importing_words: [word | socket.assigns.importing_words])
       |> start_async({:import_word, word}, fn ->
         WordImporter.import_words(scope, [word], context)
       end)}
    end
  end

  # ============================================================================
  # PRIVATE HELPERS - Audio Generation
  # ============================================================================

  # Generate audio for question if autoplay is enabled
  defp maybe_generate_audio_for_question(socket, question) do
    if socket.assigns.audio_available && socket.assigns.audio_autoplay do
      generate_audio_for_question(socket, question)
    else
      socket
    end
  end

  # Generate audio for question (handles all question types)
  defp generate_audio_for_question(socket, question) do
    language = socket.assigns.current_concept.language
    sentence = build_audio_sentence(question)

    start_async(socket, :generate_audio, fn ->
      Langseed.Audio.generate_sentence_audio(sentence, language)
    end)
  end

  # Build the sentence to generate audio for based on question type
  defp build_audio_sentence(question) do
    case question.question_type do
      "yes_no" ->
        question.question_text

      "multiple_choice" ->
        correct_word = Enum.at(question.options, String.to_integer(question.correct_answer))
        String.replace(question.question_text, "____", correct_word || "")

      _ ->
        question.question_text
    end
  end

  # ============================================================================
  # HANDLE_INFO - Practice Ready Updates
  # ============================================================================

  @impl true
  def handle_info(:check_practice_ready, socket) do
    # Schedule next check
    Process.send_after(self(), :check_practice_ready, 30_000)

    {:noreply, update_practice_ready(socket)}
  end

  @impl true
  def handle_info({:practice_updated, _data}, socket) do
    {:noreply, update_practice_ready(socket)}
  end

  # ============================================================================
  # RENDER
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20">
      <div class="p-4 max-w-lg mx-auto">
        <h1 class="text-2xl font-bold mb-6 text-center">{gettext("Practice")}</h1>

        <%= case @mode do %>
          <% :no_words -> %>
            <.no_words_card />
          <% :loading -> %>
            <.loading_card />
          <% :loading_quiz -> %>
            <.loading_card message={gettext("Generating question...")} />
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
              audio_url={@audio_url}
              audio_loading={@audio_loading}
            />
          <% :pinyin_quiz -> %>
            <.pinyin_quiz_card
              concept={@current_concept}
              pinyin_input={@pinyin_input}
              feedback={@feedback}
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

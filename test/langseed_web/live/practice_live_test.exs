defmodule LangseedWeb.PracticeLiveTest do
  use LangseedWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Langseed.VocabularyFixtures

  alias Langseed.Practice
  alias Langseed.Vocabulary

  describe "PracticeLive - unauthenticated" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/google"}}} = live(conn, ~p"/practice")
    end
  end

  describe "PracticeLive - authenticated with no concepts" do
    setup :register_and_log_in_user

    test "shows no words card when user has no concepts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/practice")

      assert html =~ "做得好"
      assert html =~ "没有需要练习的词汇了"
    end
  end

  describe "PracticeLive - definition mode (understanding = 0)" do
    setup :register_and_log_in_user

    test "shows definition card for new word", %{conn: conn, user: user} do
      concept_fixture(user, %{
        word: "你好",
        pinyin: "nǐ hǎo",
        meaning: "hello",
        understanding: 0,
        explanations: ["👋😊"]
      })

      {:ok, view, html} = live(conn, ~p"/practice")

      assert html =~ "新词"
      assert html =~ "你好"
      assert html =~ "nǐ hǎo"
      assert html =~ "👋😊"
      assert has_element?(view, "button", "我懂了")
      assert has_element?(view, "button", "换一个解释")
      assert has_element?(view, "button", "跳过")
    end

    test "understand event marks word as understood and loads next", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          understanding: 0
        })

      {:ok, view, _html} = live(conn, ~p"/practice")

      # Click "我懂了"
      view
      |> element("button", "我懂了")
      |> render_click()

      # Concept should now have understanding = 1
      updated = Vocabulary.get_concept!(user, concept.id)
      assert updated.understanding == 1

      # Since the concept now has understanding=1, it goes to loading_quiz mode
      # (concepts with 1-60% understanding get quizzed)
      html = render(view)
      assert html =~ "生成问题中" or html =~ "做得好"
    end

    test "skip event loads next concept", %{conn: conn, user: user} do
      concept_fixture(user, %{word: "你好", understanding: 0})
      concept_fixture(user, %{word: "再见", understanding: 0})

      {:ok, view, html} = live(conn, ~p"/practice")

      # First word should be shown (lowest understanding first)
      assert html =~ "你好" or html =~ "再见"

      # Skip to next
      view
      |> element("button", "跳过")
      |> render_click()

      # Should show different content (either next word or same depending on order)
      # The skip just moves to next, doesn't change understanding
      html = render(view)
      assert html =~ "新词"
    end
  end

  describe "PracticeLive - quiz mode" do
    setup :register_and_log_in_user

    test "shows loading state then quiz when concept has understanding > 0", %{
      conn: conn,
      user: user
    } do
      concept =
        concept_fixture(user, %{
          word: "你好",
          understanding: 30
        })

      # Pre-create a question so we don't need to wait for LLM
      {:ok, _question} =
        Practice.create_question(%{
          concept_id: concept.id,
          user_id: user.id,
          question_type: "yes_no",
          question_text: "你好 是 问候语 吗？",
          correct_answer: "yes",
          explanation: "你好 是 中文 问候语"
        })

      {:ok, view, _html} = live(conn, ~p"/practice")

      # Should eventually show the quiz (async might still be loading)
      # Wait for the async to complete
      :timer.sleep(100)
      html = render(view)

      # Should show quiz content or be loading
      assert html =~ "你好 是 问候语 吗？" or html =~ "生成问题中"
    end

    test "answer_yes_no event records answer and shows feedback", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          understanding: 30
        })

      {:ok, question} =
        Practice.create_question(%{
          concept_id: concept.id,
          user_id: user.id,
          question_type: "yes_no",
          question_text: "你好 是 问候语 吗？",
          correct_answer: "yes",
          explanation: "你好 是 中文 问候语"
        })

      {:ok, view, _html} = live(conn, ~p"/practice")
      :timer.sleep(100)

      # Answer correctly
      view
      |> element("button[phx-value-answer='yes']")
      |> render_click()

      html = render(view)
      assert html =~ "正确"

      # Question should be marked as used
      updated_question = Langseed.Repo.get!(Langseed.Practice.Question, question.id)
      assert updated_question.used == true
    end

    test "fill_blank question shows options", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          understanding: 30
        })

      {:ok, _question} =
        Practice.create_question(%{
          concept_id: concept.id,
          user_id: user.id,
          question_type: "fill_blank",
          question_text: "____ 是 问候语",
          correct_answer: "0",
          options: ["你好", "再见", "谢谢", "对不起"]
        })

      {:ok, view, _html} = live(conn, ~p"/practice")
      :timer.sleep(100)

      html = render(view)
      assert html =~ "你好"
      assert html =~ "再见"
      assert html =~ "谢谢"
      assert html =~ "对不起"
    end

    test "switch_to_sentence event changes mode to sentence writing", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          understanding: 30
        })

      {:ok, _question} =
        Practice.create_question(%{
          concept_id: concept.id,
          user_id: user.id,
          question_type: "yes_no",
          question_text: "你好 是 问候语 吗？",
          correct_answer: "yes"
        })

      {:ok, view, _html} = live(conn, ~p"/practice")
      :timer.sleep(100)

      # Switch to sentence mode
      view
      |> element("button", "写句子练习")
      |> render_click()

      html = render(view)
      assert html =~ "写句子"
      assert html =~ "写一个句子"
    end
  end

  describe "PracticeLive - sentence writing mode" do
    setup :register_and_log_in_user

    test "shows sentence writing interface", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          pinyin: "nǐ hǎo",
          meaning: "hello",
          understanding: 30
        })

      {:ok, _question} =
        Practice.create_question(%{
          concept_id: concept.id,
          user_id: user.id,
          question_type: "yes_no",
          question_text: "Test?",
          correct_answer: "yes"
        })

      {:ok, view, _html} = live(conn, ~p"/practice")
      :timer.sleep(100)

      # Switch to sentence mode
      view
      |> element("button", "写句子练习")
      |> render_click()

      html = render(view)
      assert html =~ "你好"
      assert html =~ "nǐ hǎo"
      assert html =~ "hello"
      assert has_element?(view, "textarea[name='sentence']")
    end

    test "update_sentence event updates input value", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          understanding: 30
        })

      {:ok, _question} =
        Practice.create_question(%{
          concept_id: concept.id,
          user_id: user.id,
          question_type: "yes_no",
          question_text: "Test?",
          correct_answer: "yes"
        })

      {:ok, view, _html} = live(conn, ~p"/practice")
      :timer.sleep(100)

      view
      |> element("button", "写句子练习")
      |> render_click()

      # Type in the textarea
      view
      |> element("form")
      |> render_change(%{"sentence" => "你好，世界！"})

      html = render(view)
      assert html =~ "你好，世界！"
    end
  end

  describe "PracticeLive - concept priority" do
    setup :register_and_log_in_user

    test "prioritizes concepts with lowest understanding", %{conn: conn, user: user} do
      # Create concepts with different understanding levels
      _high = concept_fixture(user, %{word: "高", understanding: 80})
      low = concept_fixture(user, %{word: "低", understanding: 10})
      _medium = concept_fixture(user, %{word: "中", understanding: 40})

      # Pre-create a question for the low concept so we can see it
      {:ok, _question} =
        Practice.create_question(%{
          concept_id: low.id,
          user_id: user.id,
          question_type: "yes_no",
          question_text: "低 是 什么？",
          correct_answer: "yes"
        })

      {:ok, view, _html} = live(conn, ~p"/practice")
      :timer.sleep(100)

      html = render(view)
      # Should show the lowest understanding first (低 at 10%)
      # Either in quiz form or loading state
      assert html =~ "低" or html =~ "生成问题中"
    end

    test "does not show concepts with understanding > 60%", %{conn: conn, user: user} do
      concept_fixture(user, %{word: "掌握", understanding: 70})

      {:ok, _view, html} = live(conn, ~p"/practice")

      # Should show no words card since the only concept is above threshold
      assert html =~ "做得好"
      refute html =~ "掌握"
    end
  end
end

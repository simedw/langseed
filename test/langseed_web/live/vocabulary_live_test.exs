defmodule LangseedWeb.VocabularyLiveTest do
  use LangseedWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Langseed.AccountsFixtures
  import Langseed.VocabularyFixtures

  describe "VocabularyLive - unauthenticated" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/google"}}} = live(conn, ~p"/vocabulary")
    end
  end

  describe "VocabularyLive - authenticated" do
    setup :register_and_log_in_user

    test "mounts and displays empty state when no concepts", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/vocabulary")

      assert html =~ "词汇"
      assert html =~ "还没有词汇"
      assert has_element?(view, "span.badge", "0")
    end

    test "displays concepts when user has vocabulary", %{conn: conn, user: user} do
      _concept1 = concept_fixture(user, %{word: "你好", understanding: 50})
      _concept2 = concept_fixture(user, %{word: "再见", understanding: 80})

      {:ok, view, html} = live(conn, ~p"/vocabulary")

      assert html =~ "你好"
      assert html =~ "再见"
      assert has_element?(view, "span.badge", "2")
      refute html =~ "还没有词汇"

      # Concepts should be sorted by understanding (descending), then word
      buttons = view |> element("#concepts") |> render()
      assert buttons =~ "再见"
      assert buttons =~ "你好"
    end

    test "expand event opens concept card modal", %{conn: conn, user: user} do
      concept = concept_fixture(user, %{word: "你好", pinyin: "nǐ hǎo", meaning: "hello"})

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      # Click to expand
      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      # Modal should be visible
      assert has_element?(view, "div.fixed.inset-0.bg-black\\/50")
      html = render(view)
      assert html =~ "你好"
      # Pinyin is now rendered with colored spans per syllable
      assert html =~ "nǐ"
      assert html =~ "hǎo"
    end

    test "collapse event closes concept card modal", %{conn: conn, user: user} do
      concept = concept_fixture(user, %{word: "你好"})

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      # Open modal
      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      assert has_element?(view, "div.fixed.inset-0.bg-black\\/50")

      # Close modal by clicking the backdrop
      view
      |> element("div.fixed.inset-0.bg-black\\/50")
      |> render_click()

      refute has_element?(view, "div.fixed.inset-0.bg-black\\/50")
    end

    test "delete event removes concept and shows flash", %{conn: conn, user: user} do
      concept = concept_fixture(user, %{word: "你好"})

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      # Verify concept exists
      assert has_element?(view, "button", "你好")

      # Open modal first
      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      # Arm the delete button (click once to arm)
      view
      |> element("button[phx-click='arm_delete']")
      |> render_click()

      # Confirm delete (click again to confirm)
      view
      |> element("button[phx-click='delete'][phx-value-id='#{concept.id}']")
      |> render_click()

      # Concept should be removed
      refute has_element?(view, "button", "你好")
      assert has_element?(view, "span.badge", "0")

      # Flash message should appear
      assert render(view) =~ "删除了 你好"
    end

    test "update_understanding event updates concept level", %{conn: conn, user: user} do
      concept = concept_fixture(user, %{word: "你好", understanding: 30})

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      # Open modal
      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      # Update understanding via range slider
      view
      |> element("input[type='range']")
      |> render_change(%{"value" => "75", "id" => to_string(concept.id)})

      # The slider should now show 75%
      html = render(view)
      assert html =~ "75%"
    end

    test "concepts from other users are not visible", %{conn: conn, user: _user} do
      other_user = user_fixture()
      concept_fixture(other_user, %{word: "秘密"})

      {:ok, _view, html} = live(conn, ~p"/vocabulary")

      refute html =~ "秘密"
      assert html =~ "还没有词汇"
    end

    test "displays concept explanations in expanded card", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "你好",
          explanations: ["👋😊", "见面 说 ____"]
        })

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "👋😊"
      assert html =~ "见面 说 ____"
    end

    test "displays desired words when present", %{conn: conn, user: user} do
      concept =
        concept_fixture(user, %{
          word: "喜欢",
          desired_words: ["爱", "最"]
        })

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "爱"
      assert html =~ "最"
    end

    test "filters out known words from desired words", %{conn: conn, user: user} do
      # Create a known word first
      _known_concept = concept_fixture(user, %{word: "爱"})

      # Create a concept with desired words, one of which is already known
      concept =
        concept_fixture(user, %{
          word: "喜欢",
          desired_words: ["爱", "最"]
        })

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      html = render(view)
      # "爱" should be filtered out since it's already known
      refute html =~ ~r/>爱</
      # "最" should still be shown
      assert html =~ "最"
    end

    test "hides desired words section when all words are known", %{conn: conn, user: user} do
      # Create known words
      _known1 = concept_fixture(user, %{word: "爱"})
      _known2 = concept_fixture(user, %{word: "最"})

      # Create a concept with desired words that are all already known
      concept =
        concept_fixture(user, %{
          word: "喜欢",
          desired_words: ["爱", "最"]
        })

      {:ok, view, _html} = live(conn, ~p"/vocabulary")

      view
      |> element("button[phx-value-id='#{concept.id}']")
      |> render_click()

      html = render(view)
      # The entire desired words section should be hidden
      refute html =~ "学这些词可以改进解释"
    end
  end
end

defmodule LangseedWeb.TextAnalysisLiveTest do
  use LangseedWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Langseed.AccountsFixtures
  import Langseed.VocabularyFixtures
  import Langseed.LibraryFixtures

  alias Langseed.Accounts.Scope

  defp scope_for(user), do: %Scope{user: user, language: "zh"}

  describe "TextAnalysisLive - unauthenticated" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/google"}}} = live(conn, ~p"/analyze")
    end
  end

  describe "TextAnalysisLive - authenticated" do
    setup :register_and_log_in_user

    test "mounts with empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/analyze")

      assert html =~ "分析"
      assert has_element?(view_from_html(conn, html), "textarea[name='text']")
    end

    test "segments Chinese text on input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analyze")

      # Enter Chinese text
      view
      |> element("form")
      |> render_change(%{"text" => "我喜欢学习中文"})

      html = render(view)
      # Should show the segmented text
      assert html =~ "我"
      assert html =~ "喜欢"
      assert html =~ "学习"
      assert html =~ "中文"
    end

    test "highlights known words with understanding colors", %{conn: conn, user: user} do
      # Create a known concept
      concept_fixture(user, %{word: "学习", understanding: 70})

      {:ok, view, _html} = live(conn, ~p"/analyze")

      view
      |> element("form")
      |> render_change(%{"text" => "我喜欢学习"})

      html = render(view)
      # Known word should have color styling
      assert html =~ "学习"
      # Should show word counts
      assert html =~ "知道:"
      assert html =~ "不知道:"
    end

    test "toggle_word event selects/deselects words", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analyze")

      view
      |> element("form")
      |> render_change(%{"text" => "我喜欢学习"})

      # Click to select a word
      view
      |> element("ruby[phx-click='toggle_word'][phx-value-word='喜欢']")
      |> render_click()

      html = render(view)
      # Word should be selected (has primary styling)
      assert html =~ "text-primary"

      # Click again to deselect
      view
      |> element("ruby[phx-click='toggle_word'][phx-value-word='喜欢']")
      |> render_click()

      _html = render(view)
      # Add button should not appear when no words selected
      refute has_element?(view, "button", "添加")
    end

    test "select_all_unknown selects all unknown words", %{conn: conn, user: user} do
      concept_fixture(user, %{word: "我", understanding: 50})

      {:ok, view, _html} = live(conn, ~p"/analyze")

      view
      |> element("form")
      |> render_change(%{"text" => "我喜欢学习"})

      # Select all unknown
      view
      |> element("button", "全选不知道")
      |> render_click()

      html = render(view)
      # Should show add button with count of unknown words
      assert html =~ "添加"
    end

    test "show_concept event opens concept card for known word", %{conn: conn, user: user} do
      concept_fixture(user, %{
        word: "学习",
        pinyin: "xué xí",
        meaning: "to study",
        understanding: 60
      })

      {:ok, view, _html} = live(conn, ~p"/analyze")

      view
      |> element("form")
      |> render_change(%{"text" => "我喜欢学习"})

      # Click on known word
      view
      |> element("ruby[phx-click='show_concept'][phx-value-word='学习']")
      |> render_click()

      html = render(view)
      assert html =~ "xué xí"
      assert html =~ "to study"
    end

    test "collapse event closes concept card", %{conn: conn, user: user} do
      concept_fixture(user, %{word: "学习", understanding: 60})

      {:ok, view, _html} = live(conn, ~p"/analyze")

      view
      |> element("form")
      |> render_change(%{"text" => "我喜欢学习"})

      view
      |> element("ruby[phx-click='show_concept'][phx-value-word='学习']")
      |> render_click()

      # Close the modal
      view
      |> element("div.fixed.inset-0.bg-black\\/50")
      |> render_click()

      refute has_element?(view, "div.fixed.inset-0.bg-black\\/50")
    end

    test "save_text event creates new text", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/analyze")

      view
      |> element("form")
      |> render_change(%{"text" => "这是测试文本"})

      view
      |> element("button", "保存")
      |> render_click()

      html = render(view)
      assert html =~ "已保存"

      # Should have a text in the database
      texts = Langseed.Library.list_texts(scope_for(user))
      assert length(texts) == 1
      assert hd(texts).content == "这是测试文本"
    end

    test "loads existing text via text_id param", %{conn: conn, user: user} do
      text = text_fixture(user, %{content: "保存的内容", title: "测试"})

      {:ok, _view, html} = live(conn, ~p"/analyze?text_id=#{text.id}")

      assert html =~ "保存的内容"
    end

    test "toggle_load_menu shows and hides recent texts", %{conn: conn, user: user} do
      text_fixture(user, %{title: "最近文本"})

      {:ok, view, _html} = live(conn, ~p"/analyze")

      # Open menu
      view
      |> element("button", "加载")
      |> render_click()

      html = render(view)
      assert html =~ "最近文本"
      assert html =~ "新文本"

      # Close menu
      view
      |> element("div.fixed.inset-0.z-40")
      |> render_click()

      refute has_element?(view, "div.absolute.left-0.top-full")
    end

    test "new_text event clears current text", %{conn: conn, user: user} do
      text = text_fixture(user, %{content: "旧内容"})

      {:ok, view, html} = live(conn, ~p"/analyze?text_id=#{text.id}")
      assert html =~ "旧内容"

      # Open menu and click new text
      view
      |> element("button", "加载")
      |> render_click()

      view
      |> element("button", "新文本")
      |> render_click()

      html = render(view)
      refute html =~ "旧内容"
    end
  end

  describe "TextAnalysisLive - isolation" do
    setup :register_and_log_in_user

    test "cannot access other user's texts", %{conn: conn} do
      other_user = user_fixture()
      text = text_fixture(other_user, %{content: "秘密内容"})

      {:ok, _view, html} = live(conn, ~p"/analyze?text_id=#{text.id}")

      # Should show error flash, not the content
      assert html =~ "Text not found"
      refute html =~ "秘密内容"
    end
  end

  # Helper to get a view from rendered html for assertions
  defp view_from_html(conn, _html) do
    {:ok, view, _} = live(conn, ~p"/analyze")
    view
  end
end

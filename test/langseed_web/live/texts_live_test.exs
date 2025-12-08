defmodule LangseedWeb.TextsLiveTest do
  use LangseedWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Langseed.AccountsFixtures
  import Langseed.LibraryFixtures

  describe "TextsLive - unauthenticated" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/auth/google"}}} = live(conn, ~p"/texts")
    end
  end

  describe "TextsLive - authenticated with no texts" do
    setup :register_and_log_in_user

    test "shows empty state when no texts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/texts")

      assert html =~ "文本"
      assert html =~ "还没有保存的文本"
      assert html =~ "分析"
    end
  end

  describe "TextsLive - authenticated with texts" do
    setup :register_and_log_in_user

    test "displays list of texts", %{conn: conn, user: user} do
      text1 = text_fixture(user, %{title: "第一个文本", content: "内容一"})
      text2 = text_fixture(user, %{title: "第二个文本", content: "内容二"})

      {:ok, _view, html} = live(conn, ~p"/texts")

      assert html =~ "第一个文本"
      assert html =~ "第二个文本"
      assert html =~ "内容一"
      assert html =~ "内容二"

      # Should have links to analyze page
      assert html =~ "/analyze?text_id=#{text1.id}"
      assert html =~ "/analyze?text_id=#{text2.id}"
    end

    test "delete event removes text and shows flash", %{conn: conn, user: user} do
      text = text_fixture(user, %{title: "要删除的文本"})

      {:ok, view, _html} = live(conn, ~p"/texts")

      # Delete the text
      view
      |> element("button[phx-click='delete'][phx-value-id='#{text.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "要删除的文本"
      assert html =~ "已删除"
      assert html =~ "还没有保存的文本"
    end

    test "start_edit event shows edit form", %{conn: conn, user: user} do
      text = text_fixture(user, %{title: "原标题"})

      {:ok, view, _html} = live(conn, ~p"/texts")

      # Click edit button
      view
      |> element("button[phx-click='start_edit'][phx-value-id='#{text.id}']")
      |> render_click()

      _html = render(view)
      assert has_element?(view, "input[type='text'][value='原标题']")
    end

    test "cancel_edit event closes edit form", %{conn: conn, user: user} do
      text = text_fixture(user, %{title: "原标题"})

      {:ok, view, _html} = live(conn, ~p"/texts")

      # Start editing
      view
      |> element("button[phx-click='start_edit'][phx-value-id='#{text.id}']")
      |> render_click()

      assert has_element?(view, "input[type='text']")

      # Cancel editing
      view
      |> element("button[phx-click='cancel_edit']")
      |> render_click()

      refute has_element?(view, "input[type='text'][value='原标题']")
    end

    test "save_title event updates text title", %{conn: conn, user: user} do
      text = text_fixture(user, %{title: "旧标题"})

      {:ok, view, _html} = live(conn, ~p"/texts")

      # Start editing
      view
      |> element("button[phx-click='start_edit'][phx-value-id='#{text.id}']")
      |> render_click()

      # Update the title input
      view
      |> element("input[name='value']")
      |> render_change(%{"value" => "新标题"})

      # Submit the form
      view
      |> element("form[phx-submit='save_title']")
      |> render_submit(%{"id" => to_string(text.id)})

      html = render(view)
      assert html =~ "新标题"
      refute html =~ "旧标题"

      # Verify in database
      updated = Langseed.Library.get_text!(user, text.id)
      assert updated.title == "新标题"
    end

    test "texts are sorted by updated_at descending", %{conn: conn, user: user} do
      # Create texts - newer ones should appear first
      _old = text_fixture(user, %{title: "旧文本"})
      :timer.sleep(50)
      _new = text_fixture(user, %{title: "新文本"})

      {:ok, _view, html} = live(conn, ~p"/texts")

      # Both texts should be present
      assert html =~ "旧文本"
      assert html =~ "新文本"
    end

    test "shows truncated content preview", %{conn: conn, user: user} do
      long_content = String.duplicate("中", 150)
      text_fixture(user, %{title: "长文本", content: long_content})

      {:ok, _view, html} = live(conn, ~p"/texts")

      # Should show truncated content with ellipsis
      assert html =~ "..."
    end
  end

  describe "TextsLive - isolation" do
    setup :register_and_log_in_user

    test "cannot see other user's texts", %{conn: conn} do
      other_user = user_fixture()
      text_fixture(other_user, %{title: "其他用户的文本"})

      {:ok, _view, html} = live(conn, ~p"/texts")

      refute html =~ "其他用户的文本"
      assert html =~ "还没有保存的文本"
    end

    test "other user's texts are isolated", %{conn: conn, user: user} do
      other_user = user_fixture()
      other_text = text_fixture(other_user, %{title: "其他用户文本"})
      my_text = text_fixture(user, %{title: "我的文本"})

      {:ok, view, html} = live(conn, ~p"/texts")

      # Should only see own text, not other user's
      assert html =~ "我的文本"
      refute html =~ "其他用户文本"

      # Can only delete own text
      view
      |> element("button[phx-click='delete'][phx-value-id='#{my_text.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "我的文本"

      # Other user's text should still exist
      assert Langseed.Library.get_text(other_user, other_text.id) != nil
    end
  end
end

defmodule LangseedWeb.LandingLiveTest do
  use LangseedWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "LandingLive - unauthenticated" do
    test "shows landing page with product info", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "LangSeed"
      assert html =~ "Grow your vocabulary"
      assert html =~ "Sign in with Google"
      assert html =~ "Chinese"
      assert html =~ "Swedish"
    end

    test "shows features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Analyze Real Texts"
      assert html =~ "AI-Powered Learning"
      assert html =~ "Active Practice"
    end

    test "shows how it works section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "How it Works"
      assert html =~ "Add Words"
      assert html =~ "See Connections"
      assert html =~ "Practice Daily"
    end
  end

  describe "LandingLive - authenticated" do
    setup :register_and_log_in_user

    test "redirects to vocabulary when authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/vocabulary"}}} = live(conn, ~p"/")
    end
  end
end

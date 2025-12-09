defmodule LangseedWeb.LanguageController do
  use LangseedWeb, :controller

  alias Langseed.Accounts

  def update(conn, %{"language" => language}) do
    user = conn.assigns.current_scope.user
    redirect_to = get_redirect_path(conn)

    case Accounts.update_selected_language(user, language) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Language updated")
        |> redirect(to: redirect_to)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to update language")
        |> redirect(to: redirect_to)
    end
  end

  defp get_redirect_path(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] ->
        uri = URI.parse(referer)
        uri.path || "/"

      _ ->
        "/"
    end
  end
end


defmodule LangseedWeb.AdminAuth do
  @moduledoc """
  Admin authentication plug and LiveView mount hook.
  Restricts access to admin-only routes.
  """

  use LangseedWeb, :verified_routes

  @doc """
  Checks if a user email is in the admin whitelist.
  """
  def admin?(nil), do: false
  def admin?(%{email: email}), do: email in admin_emails()

  defp admin_emails do
    Application.get_env(:langseed, :admin, [])[:emails] || []
  end

  @doc """
  LiveView on_mount callback for admin routes.
  """
  def on_mount(:require_admin, _params, _session, socket) do
    if socket.assigns[:current_scope] && admin?(socket.assigns.current_scope.user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You don't have access to this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end
end

defmodule LangseedWeb.AuthController do
  use LangseedWeb, :controller
  plug Ueberauth

  alias Langseed.Accounts
  alias LangseedWeb.UserAuth

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    email = auth.info.email
    name = auth.info.name

    case Accounts.get_user_by_email(email) do
      nil ->
        # Create new user
        case Accounts.register_user_oauth(%{email: email, name: name}) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Welcome, #{name}!")
            |> UserAuth.log_in_user(user)

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Failed to create account.")
            |> redirect(to: ~p"/")
        end

      user ->
        # Existing user
        conn
        |> put_flash(:info, "Welcome back, #{user.email}!")
        |> UserAuth.log_in_user(user)
    end
  end
end

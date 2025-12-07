defmodule LangseedWeb.AuthController do
  use LangseedWeb, :controller
  plug Ueberauth

  alias Langseed.Accounts
  alias Langseed.Vocabulary.Seeds
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
            # Add seed vocabulary for new user
            {:ok, word_count} = Seeds.create_for_user(user)

            conn
            |> put_flash(:info, "欢迎 #{name}! 你有 #{word_count} 个基础词汇开始学习。")
            |> UserAuth.log_in_user(user)

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Failed to create account.")
            |> redirect(to: ~p"/")
        end

      user ->
        # Existing user
        conn
        |> put_flash(:info, "欢迎回来, #{name || user.email}!")
        |> UserAuth.log_in_user(user)
    end
  end
end

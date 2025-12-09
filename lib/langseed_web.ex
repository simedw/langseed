defmodule LangseedWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use LangseedWeb, :controller
      use LangseedWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: LangseedWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
      unquote(live_view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: LangseedWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import LangseedWeb.CoreComponents
      # Shared components (speak_button, quality_stars, concept_card, etc.)
      import LangseedWeb.SharedComponents

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias LangseedWeb.Layouts

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  defp live_view_helpers do
    quote do
      # Gets the current scope from socket assigns.
      # Returns nil if not authenticated.
      defp current_scope(socket) do
        socket.assigns[:current_scope]
      end

      # Gets the current user from socket assigns.
      # Returns nil if not authenticated.
      defp current_user(socket) do
        case socket.assigns[:current_scope] do
          %{user: user} -> user
          _ -> nil
        end
      end
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: LangseedWeb.Endpoint,
        router: LangseedWeb.Router,
        statics: LangseedWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

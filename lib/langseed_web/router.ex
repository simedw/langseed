defmodule LangseedWeb.Router do
  use LangseedWeb, :router

  import LangseedWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LangseedWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug LangseedWeb.Plugs.SetLocale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LangseedWeb do
    pipe_through :browser

    # All app routes require authentication
    live_session :authenticated,
      layout: {LangseedWeb.Layouts, :app},
      on_mount: [{LangseedWeb.UserAuth, :require_authenticated_user}] do
      live "/", VocabularyLive
      live "/graph", VocabularyGraphLive
      live "/analyze", TextAnalysisLive
      live "/texts", TextsLive
      live "/practice", PracticeLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LangseedWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:langseed, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LangseedWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # OAuth routes
  scope "/auth", LangseedWeb do
    pipe_through [:browser]

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/", LangseedWeb do
    pipe_through [:browser]

    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/", LangseedWeb do
    pipe_through [:browser, :require_authenticated_user]

    put "/language", LanguageController, :update
  end
end

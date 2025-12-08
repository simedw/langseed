defmodule Langseed.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LangseedWeb.Telemetry,
      Langseed.Repo,
      {DNSCluster, query: Application.get_env(:langseed, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Langseed.PubSub},
      # HSK level lookup service
      Langseed.HSK,
      # Oban for background jobs
      {Oban, Application.fetch_env!(:langseed, Oban)},
      # Start to serve requests, typically the last entry
      LangseedWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Langseed.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LangseedWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

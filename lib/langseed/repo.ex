defmodule Langseed.Repo do
  use Ecto.Repo,
    otp_app: :langseed,
    adapter: Ecto.Adapters.Postgres
end

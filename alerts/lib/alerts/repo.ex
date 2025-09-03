defmodule Alerts.Repo do
  use Ecto.Repo,
    otp_app: :alerts,
    adapter: Ecto.Adapters.Postgres
end

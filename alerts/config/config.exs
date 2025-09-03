# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :alerts,
  ecto_repos: [Alerts.Repo],
  generators: [timestamp_type: :utc_datetime],
  # encryption_key is configured in config/runtime.exs
  # Database drivers configuration
  database_drivers: [
    {"MariaDB Unicode", "MariaDB Unicode"},
    {"PostgreSQL Unicode", "PostgreSQL Unicode"}, 
    {"SQL Server", "SQL Server"},
    {"SQL Server Native Client 11.0", "SQL Server Native Client 11.0"}
  ]

# Configures the endpoint
config :alerts, AlertsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AlertsWeb.ErrorHTML, json: AlertsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Alerts.PubSub,
  live_view: [signing_salt: "z7N8+fxY"]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

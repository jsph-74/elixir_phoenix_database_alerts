import Config


# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :alerts, Alerts.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DATABASE_HOST", "db-test"),
  port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
  database: "alerts_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2


# We don't run a server during test. If one is required,
# you can enable the server option below.
config :alerts, AlertsWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4002")],
  secret_key_base: "h44yMQRJyQW1VilrwNaIuGB9SgtlhQg0yCHBGiDmfr8OxcKy+/3bObAn4KIC/ebm",
  server: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

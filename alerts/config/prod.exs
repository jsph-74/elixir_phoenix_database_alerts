import Config

# Do not print debug messages in production
config :logger, level: :info

# Force SSL in production (compile-time configuration)
config :alerts, AlertsWeb.Endpoint,
  force_ssl: [
    hsts: true,
    expires: 31_536_000,  # 1 year
    preload: true,
    subdomains: true
  ]

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

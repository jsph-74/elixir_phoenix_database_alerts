import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# Configure encryption key at runtime (not compile time)
encryption_key =
  # Try environment variable first (for docker-compose mode), then Docker secrets (for stack mode)
  case System.get_env("DATA_SOURCE_ENCRYPTION_KEY") do
    nil ->
      case File.read("/run/secrets/data_source_encryption_key") do
        {:ok, key} ->
          String.trim(key)
        {:error, _} ->
          raise """
          DATA_SOURCE_ENCRYPTION_KEY environment variable or Docker secret is missing.
          Start the environment first: ./bin/#{config_env()}/startup.sh
          """
      end
    key when is_binary(key) ->
      String.trim(key)
  end

config :alerts,
  encryption_key: encryption_key

# SSL/HTTPS Configuration - Auto-detect certificates
ssl_env = System.get_env("MIX_ENV", "dev")
cert_path = "/app/priv/ssl/#{ssl_env}/cert.pem"
key_path = "/app/priv/ssl/#{ssl_env}/key.pem"

# Configure HTTP/HTTPS based on SSL certificate availability
if File.exists?(cert_path) and File.exists?(key_path) do
  https_port = String.to_integer(System.get_env("HTTPS_PORT", "4001"))
  http_port = String.to_integer(System.get_env("HTTP_PORT", "4000"))
  
  # SSL available: Configure both HTTP and HTTPS
  endpoint_config = [
    https: [
      ip: {0, 0, 0, 0},
      port: https_port,
      keyfile: key_path,
      certfile: cert_path
    ],
    http: [ip: {0, 0, 0, 0}, port: http_port],
    url: [host: System.get_env("PHX_HOST", "localhost"), port: https_port, scheme: "https"]
  ]
  
  # Note: force_ssl is configured in prod.exs (compile-time config)
  
  config :alerts, AlertsWeb.Endpoint, endpoint_config
  
  # Log SSL status
  redirect_msg = if ssl_env == "prod", do: " (HTTP redirects to HTTPS)", else: ""
  IO.puts("🔒 SSL certificates detected - HTTPS on port #{https_port}, HTTP on port #{http_port}#{redirect_msg}")
else
  # No SSL: Configure HTTP only
  http_port = String.to_integer(System.get_env("HTTP_PORT", "4000"))
  
  config :alerts, AlertsWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: http_port],
    url: [host: System.get_env("PHX_HOST", "localhost"), port: http_port, scheme: "http"]
  
  IO.puts("📄 HTTP only on port #{http_port}")
end

# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/alerts_new start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :alerts, AlertsWeb.Endpoint, server: true
end

if config_env() == :prod do
  config :alerts, Alerts.Repo,
    username: System.get_env("DATABASE_USER") || "postgres",
    password: System.get_env("DATABASE_PASSWORD") || "postgres",
    hostname: System.get_env("DATABASE_HOST") || "db",
    database: System.get_env("DATABASE_NAME") || "alerts_prod",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use Docker secrets instead.
  secret_key_base =
    # Try environment variable first (for docker-compose mode), then Docker secrets (for stack mode)
    case System.get_env("SECRET_KEY_BASE") do
      nil ->
        case File.read("/run/secrets/secret_key_base") do
          {:ok, key} ->
            String.trim(key)
          {:error, _} ->
            raise """
            SECRET_KEY_BASE environment variable or Docker secret is missing.
            Start the environment first: ./bin/prod/startup.sh
            """
        end
      key when is_binary(key) ->
        String.trim(key)
    end

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :alerts, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # SSL certificate paths for production
  prod_cert_path = "/app/priv/ssl/prod/cert.pem"
  prod_key_path = "/app/priv/ssl/prod/key.pem"
  
  if File.exists?(prod_cert_path) and File.exists?(prod_key_path) do
    # SSL available: Configure both HTTP and HTTPS for production with proper redirect
    https_port = String.to_integer(System.get_env("HTTPS_PORT", "4005"))
    http_port = String.to_integer(System.get_env("HTTP_PORT", "4004"))
    
    config :alerts, AlertsWeb.Endpoint,
      url: [host: host, port: https_port, scheme: "https"],
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: http_port
      ],
      https: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: https_port,
        cipher_suite: :strong,
        certfile: prod_cert_path,
        keyfile: prod_key_path
      ],
      force_ssl: [
        rewrite_on: [:x_forwarded_proto],
        hsts: true,
        expires: 31_536_000,
        preload: false,
        subdomains: false
      ],
      server: true,
      code_reloader: false,
      secret_key_base: secret_key_base
  else
    # No SSL: Configure HTTP only for production
    config :alerts, AlertsWeb.Endpoint,
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      url: [host: host, port: port, scheme: "http"],
      secret_key_base: secret_key_base
  end

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :alerts, AlertsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :alerts, AlertsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end

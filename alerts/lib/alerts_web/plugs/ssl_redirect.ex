defmodule AlertsWeb.Plugs.SSLRedirect do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.scheme == :http and ssl_configured?() do
      # Get HTTPS port from environment or default to 4005
      https_port = System.get_env("HTTPS_PORT", "4005")
      redirect_url = "https://" <> conn.host <> ":" <> https_port <> conn.request_path
      conn
      |> put_resp_header("location", redirect_url)
      |> send_resp(301, "Redirecting to HTTPS...")
      |> halt()
    else
      conn
    end
  end

  defp ssl_configured? do
    # Check if SSL certificates exist (same logic as runtime.exs)
    cert_path = "/app/priv/ssl/prod/cert.pem"
    key_path = "/app/priv/ssl/prod/key.pem"
    File.exists?(cert_path) and File.exists?(key_path)
  end
end
defmodule Alerts.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    base_children = [
      AlertsWeb.Telemetry,
      Alerts.Repo,
      {DNSCluster, query: Application.get_env(:alerts, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Alerts.PubSub}
    ]
    
    # Validate master password if configured (after Repo starts)
    :ok = validate_master_password_on_startup()
    
    # Only start scheduler and version supervisor in non-test environments
    children = case Mix.env() do
      :test -> 
        base_children ++ [AlertsWeb.Endpoint]
      _ -> 
        base_children ++ [
          Alerts.Scheduler,
          Alerts.VersionSupervisor,
          AlertsWeb.Endpoint
        ]
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alerts.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AlertsWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp validate_master_password_on_startup do
    case Alerts.Business.MasterPassword.master_password_configured?() do
      false ->
        # No master password configured, proceed normally
        IO.puts("📄 Starting application without master password protection")
        :ok
        
      true ->
        # Master password is configured - login screen will handle authentication
        IO.puts("🔐 Master password protection enabled - login required")
        :ok
    end
  rescue
    error ->
      # If there's any error checking master password (e.g., DB not ready), 
      # proceed without validation but log the issue
      IO.puts("⚠️  Could not check master password: #{inspect(error)}")
      :ok
  end
end

ExUnit.start()

# Set up Ecto sandbox for database tests
Ecto.Adapters.SQL.Sandbox.mode(Alerts.Repo, :manual)
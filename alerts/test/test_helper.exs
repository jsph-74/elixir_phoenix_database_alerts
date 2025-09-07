ExUnit.start()

# Set up Ecto sandbox for database tests (works in both test and dev environments)
Ecto.Adapters.SQL.Sandbox.mode(Alerts.Repo, :manual)
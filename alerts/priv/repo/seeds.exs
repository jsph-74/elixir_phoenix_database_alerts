# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Alerts.Repo.insert!(%Alerts.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Alerts.Business.DataSources
alias Alerts.Business.Alerts, as: AlertsBusiness
alias Alerts.Repo
import Ecto.Query

# Verify encryption key is available
case System.get_env("DATA_SOURCE_ENCRYPTION_KEY") do
  nil ->
    IO.puts("❌ ERROR: DATA_SOURCE_ENCRYPTION_KEY environment variable not set!")
    IO.puts("Please run: bin/init_encryption_key.sh to generate a key")
    IO.puts("Then set: export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts/encryption_key.txt)")
    System.halt(1)
  key ->
    IO.puts("✅ Using encryption key from environment")
    IO.puts("Key: #{String.slice(key, 0, 8)}... (truncated for security)")
end

# Clear existing data (for clean seeding)
Repo.delete_all(Alerts.Business.DB.Alert)
Repo.delete_all(Alerts.Business.DB.DataSource)

# Create sample data sources with encrypted passwords (realistic test databases)
data_sources = [
  %{
    name: "ecommerce_mysql",
    display_name: "E-commerce Analytics Database",
    driver: "MariaDB Unicode",
    server: "test_mysql",
    database: "test",
    username: "monitor_user",
    password: "monitor_pass",
    port: 3306,
    additional_params: %{"CHARSET" => "UTF8"}
  },
  %{
    name: "investment_postgres",
    display_name: "Investment Portfolio Database",
    driver: "PostgreSQL Unicode",
    server: "test_postgres",
    database: "test",
    username: "monitor_user",
    password: "monitor_pass",
    port: 5433,
    additional_params: %{}
  },
  # Broken data source for E2E validation testing
  %{
    name: "broken_mysql",
    display_name: "Broken MySQL Database", 
    driver: "MariaDB Unicode",
    server: "test_mysql",
    database: "nonexistent_database",
    username: "monitor_user",
    password: "monitor_pass", 
    port: 3306,
    additional_params: %{"CHARSET" => "UTF8"}
  }
]

# Insert data sources - passwords will be automatically encrypted
IO.puts("Creating data sources with encrypted passwords...")

Enum.each(data_sources, fn data_source_params ->
  case DataSources.create_data_source(data_source_params) do
    {:ok, data_source} ->
      IO.puts("✓ Created data source: #{data_source.display_name} (#{data_source.name})")
    {:error, changeset} ->
      IO.puts("✗ Failed to create data source #{data_source_params.name}:")
      IO.inspect(changeset.errors)
  end
end)

# Create sample alerts that showcase the application's capabilities
IO.puts("\nCreating sample alerts to demonstrate application value...")

# Get the created data sources
ecommerce_ds = Repo.get_by!(Alerts.Business.DB.DataSource, name: "ecommerce_mysql")
investment_ds = Repo.get_by!(Alerts.Business.DB.DataSource, name: "investment_postgres")
broken_ds = Repo.get_by!(Alerts.Business.DB.DataSource, name: "broken_mysql")

# E-commerce alerts
ecommerce_alerts = [
  %{
    "name" => "Low Inventory Alert",
    "context" => "ecommerce",
    "description" => "Alert when any product has less than 10 units in stock",
    "query" => "
      SELECT
        p.name as product_name,
        i.quantity_on_hand
      FROM products p
      JOIN inventory i ON p.id = i.product_id
      WHERE i.quantity_on_hand < 10",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 0,
    "schedule" => ""
  },
  %{
    "name" => "Failed Payment Transactions",
    "context" => "ecommerce",
    "description" => "Alert when too many payment failures occur",
    "query" => "
      SELECT *
      FROM payment_transactions
      WHERE status = 'failed'
        AND processed_at > DATE_SUB(NOW(), INTERVAL 1 DAY)",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 3,  # Alert if more than 3 failed payments
    "schedule" => "0 */2 * * *"  # Every 2 hours
  },
  %{
    "name" => "Stale Pending Orders",
    "context" => "ecommerce",
    "description" => "Alert for orders stuck in pending status over 24 hours",
    "query" => "
      SELECT *
      FROM orders
      WHERE status = 'pending'
        AND order_date < DATE_SUB(NOW(), INTERVAL 1 DAY)",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 0,
    "schedule" => "0 9,17 * * *"  # 9 AM and 5 PM daily
  },
  %{
    "name" => "Suspicious High Value Orders",
    "context" => "ecommerce",
    "description" => "Alert for potential fraud - multiple high-value orders in short time",
    "query" => "
      SELECT *
      FROM orders
      WHERE total_amount > 1000
        AND order_date > DATE_SUB(NOW(), INTERVAL 1 HOUR)",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 2,  # Alert if more than 2 high-value orders per hour
    "schedule" => "0 * * * *"  # Every hour
  }
]

# Investment portfolio alerts - mixed scenarios for testing
investment_alerts = [
  %{
    "name" => "Portfolio Large Daily Loss",
    "context" => "portfolios",
    "description" => "Alert when more than 2 portfolios lose over 5% in a day (BAD scenario - will trigger)",
    "query" => "
      SELECT
        p.name,
        pp.daily_return_pct
      FROM portfolios p
      JOIN portfolio_performance pp ON p.id = pp.portfolio_id
      WHERE pp.date = CURRENT_DATE
        AND pp.daily_return_pct < -5.0",
    "data_source_id" => investment_ds.id,
    "threshold" => 2,  # Alert if MORE than 2 portfolios have large losses
    "schedule" => "0 17 * * 1-5"  # Weekdays at 5 PM (market close)
  },
  %{
    "name" => "High Portfolio Volatility",
    "context" => "portfolios", 
    "description" => "Alert when more than 1 portfolio exceeds 25% volatility (UNDER THRESHOLD - won't trigger)",
    "query" => "
      SELECT
        p.name,
        rm.volatility_30d
      FROM portfolios p
      JOIN risk_metrics rm ON p.id = rm.portfolio_id
      WHERE rm.calculation_date = CURRENT_DATE
        AND rm.volatility_30d > 25.0",
    "data_source_id" => investment_ds.id,
    "threshold" => 5,  # Alert if MORE than 5 portfolios (unlikely - under threshold)
    "schedule" => "0 9 * * 1-5"  # Weekdays at 9 AM
  },
  %{
    "name" => "Large Position Losses",
    "context" => "portfolios",
    "description" => "Alert for any individual position with losses over $10,000 (GOOD - will trigger immediately)",
    "query" => "
      SELECT
        po.symbol,
        po.unrealized_gain_loss,
        p.name as portfolio
      FROM positions po
      JOIN portfolios p ON po.portfolio_id = p.id
      WHERE po.unrealized_gain_loss < -10000",
    "data_source_id" => investment_ds.id,
    "threshold" => 0,  # Alert if ANY positions found
    "schedule" => "0 16 * * 1-5"  # Weekdays at 4 PM
  },
  %{
    "name" => "Failed Trade Executions",
    "context" => "portfolios",
    "description" => "Alert when more than 3 trades fail (UNDER THRESHOLD - won't trigger unless many failures)",
    "query" => "
      SELECT *
      FROM trades
      WHERE status = 'failed'
        AND trade_date > CURRENT_DATE - INTERVAL '1 day'",
    "data_source_id" => investment_ds.id,
    "threshold" => 3,  # Alert if MORE than 3 failed trades
    "schedule" => "0 */4 * * *"  # Every 4 hours
  },
  %{
    "name" => "Portfolio Concentration Risk",
    "context" => "portfolios",
    "description" => "Alert for any portfolio over 80% concentration (BAD scenario - will trigger)",
    "query" => "
      SELECT
        p.name,
        rm.top_10_concentration
      FROM portfolios p
      JOIN risk_metrics rm ON p.id = rm.portfolio_id
      WHERE rm.calculation_date = CURRENT_DATE
        AND rm.top_10_concentration > 80.0",
    "data_source_id" => investment_ds.id,
    "threshold" => 0,  # Alert if ANY concentrated portfolios found
    "schedule" => "0 7 * * 1"  # Monday at 7 AM (weekly check)
  },
  %{
    "name" => "Broken Query Alert",
    "context" => "system",
    "description" => "Alert with intentionally broken SQL to test error handling",
    "query" => "SELECT nonexistent_column FROM fake_table WHERE bad_syntax",
    "data_source_id" => investment_ds.id,
    "threshold" => 0,
    "schedule" => "0 */6 * * *"
  },
  # Broken database connection alert commented out for E2E test stability
  # %{
  #   "name" => "Broken Database Connection Alert", 
  #   "context" => "system",
  #   "description" => "Alert that tries to connect to nonexistent database to test connection errors",
  #   "query" => "SELECT 1 as test",
  #   "data_source_id" => broken_ds.id,
  #   "threshold" => 0,
  #   "schedule" => "0 */8 * * *"
  # }
]

# Test alerts with fixed names for E2E test reliability
# Each test gets its own dedicated seeded alert (READ-ONLY for tests)
test_alerts = [
  %{
    "name" => "1-test-sql-diff-history",
    "context" => "test",
    "description" => "For testing SQL diff timeline behavior",
    "query" => "SELECT 1 as initial_query",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 2,
    "schedule" => ""
  },
  %{
    "name" => "2-test-sql-diff-multiple",
    "context" => "test", 
    "description" => "For testing multiple SQL changes",
    "query" => "SELECT 1 as version_one",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 2,
    "schedule" => ""
  },
  %{
    "name" => "3-test-sql-diff-non-sql",
    "context" => "test",
    "description" => "For testing non-SQL field changes",
    "query" => "SELECT 1 as constant_query", 
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 2,
    "schedule" => ""
  },
  %{
    "name" => "4-test-timeline-workflow",
    "context" => "test",
    "description" => "For testing timeline workflow behavior",
    "query" => "SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5",
    "data_source_id" => ecommerce_ds.id, 
    "threshold" => 10,
    "schedule" => ""
  },
  %{
    "name" => "5-test-validation-broken-sql",
    "context" => "test",
    "description" => "For testing validation with bad SQL",
    "query" => "SELECT 1 as valid_sql",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 2,
    "schedule" => ""
  },
  %{
    "name" => "6-test-validation-lifecycle",
    "context" => "test", 
    "description" => "For testing alert lifecycle transitions",
    "query" => "SELECT 1 WHERE 1=0",
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 5,
    "schedule" => ""
  },
  %{
    "name" => "7-test-broken-connection",
    "context" => "test",
    "description" => "For testing broken connection status",
    "query" => "SELECT 1 as test_value",
    "data_source_id" => ecommerce_ds.id,  # Will be changed to broken after creation
    "threshold" => 0,
    "schedule" => ""
  },
  %{
    "name" => "8-test-broken-sql",
    "context" => "test",
    "description" => "For testing broken SQL status", 
    "query" => "SELECT 1 as test_value", # Will be changed to broken after creation
    "data_source_id" => ecommerce_ds.id,
    "threshold" => 0,
    "schedule" => ""
  }
]

# Normalize queries to match EXACTLY what the web app processing does
# This replicates the trim_query function from helpers.ex
normalize_query = fn query ->
  query
  |> String.trim()
  |> String.trim("\n")
  |> String.trim()
end

# Create all alerts with normalized queries
all_alerts = ecommerce_alerts ++ investment_alerts ++ test_alerts

Enum.each(all_alerts, fn alert_params ->
  # Normalize the query to match web app format
  normalized_params = Map.update!(alert_params, "query", normalize_query)
  
  case AlertsBusiness.create(normalized_params) do
    {:ok, alert} ->
      IO.puts("✓ Created alert: #{alert.name} (#{alert.context})")
    {:error, changeset} ->
      IO.puts("✗ Failed to create alert #{alert_params["name"]}:")
      IO.inspect(changeset.errors)
  end
end)

# Now break the specific test alerts after they're created
IO.puts("\\nBreaking test alerts for testing purposes...")

# Break alert 7 by changing data source to broken one
broken_connection_alert = Repo.get_by!(Alerts.Business.DB.Alert, name: "7-test-broken-connection")
from(a in Alerts.Business.DB.Alert, where: a.id == ^broken_connection_alert.id)
|> Repo.update_all(set: [data_source_id: broken_ds.id])
IO.puts("✓ Broke connection for: 7-test-broken-connection")

# Break alert 8 by changing SQL to invalid query
broken_sql_alert = Repo.get_by!(Alerts.Business.DB.Alert, name: "8-test-broken-sql")
from(a in Alerts.Business.DB.Alert, where: a.id == ^broken_sql_alert.id)
|> Repo.update_all(set: [query: "SELECT * FROM table_that_does_not_exist_anywhere"])
IO.puts("✓ Broke SQL for: 8-test-broken-sql")

IO.puts("\n🎉 Seeding complete!")
IO.puts("   • #{length(data_sources)} data sources created")
IO.puts("   • #{length(all_alerts)} sample alerts created")
IO.puts("\n💡 Alert contexts for easy grouping:")
IO.puts("   📊 ecommerce: inventory, payment failures, stale orders, fraud detection") 
IO.puts("   📈 portfolios: performance losses, volatility, concentration, trade failures")
IO.puts("   🧪 test: dedicated alerts for E2E testing (#{length(test_alerts)} alerts)")

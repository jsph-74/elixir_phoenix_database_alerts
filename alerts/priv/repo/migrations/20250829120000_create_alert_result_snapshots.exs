defmodule Alerts.Repo.Migrations.CreateAlertResultSnapshots do
  use Ecto.Migration

  def change do
    create table(:alert_result_snapshots) do
      add :alert_id, references(:alert, on_delete: :delete_all), null: false
      add :executed_at, :utc_datetime, null: false
      add :result_hash, :string, null: false
      add :row_count, :integer, null: false
      add :total_rows, :integer, null: false
      add :is_truncated, :boolean, default: false, null: false
      add :status, :string, null: false
      add :error_message, :text
      add :csv_data, :text, null: false, default: ""

      timestamps()
    end

    create index(:alert_result_snapshots, [:alert_id, :executed_at])
    create index(:alert_result_snapshots, [:result_hash])
    create index(:alert_result_snapshots, [:alert_id, :inserted_at])
  end
end
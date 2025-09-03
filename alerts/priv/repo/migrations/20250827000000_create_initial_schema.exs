defmodule Alerts.Repo.Migrations.CreateInitialSchema do
  use Ecto.Migration

  def change do
    # Create data_sources table
    create table(:data_sources) do
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :driver, :string, null: false
      add :server, :string, null: false
      add :database, :string, null: false
      add :username, :string, null: false
      add :password, :string  # encrypted password
      add :port, :integer, null: false
      add :additional_params, :map, default: %{}

      timestamps()
    end

    # Create alert table
    create table(:alert) do
      add :context, :string, null: false
      add :name, :string, null: false
      add :query, :string, null: false
      add :description, :string, null: false
      add :last_run, :naive_datetime
      add :results_size, :integer
      add :threshold, :integer
      add :schedule, :string
      add :status, :string
      add :data_source_id, references(:data_sources, on_delete: :delete_all), null: false
      add :alert_public_id, :uuid, null: false
      add :lifecycle_status, :string, default: "current", null: false

      timestamps()
    end

    # Add constraints and indexes
    create unique_index(:data_sources, [:name])
    create index(:alert, [:context])
    create index(:alert, [:alert_public_id])
    create index(:alert, [:lifecycle_status])
    create index(:alert, [:data_source_id])
    create index(:alert, [:schedule])
  end
end

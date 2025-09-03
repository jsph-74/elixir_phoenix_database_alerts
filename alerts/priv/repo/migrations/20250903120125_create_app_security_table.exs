defmodule Alerts.Repo.Migrations.CreateAppSecurityTable do
  use Ecto.Migration

  def change do
    create table(:app_security) do
      add :key_type, :string, null: false
      add :encrypted_value, :binary, null: false
      add :created_at, :naive_datetime, null: false
      add :last_changed, :naive_datetime, null: false
    end

    create unique_index(:app_security, [:key_type])
  end
end

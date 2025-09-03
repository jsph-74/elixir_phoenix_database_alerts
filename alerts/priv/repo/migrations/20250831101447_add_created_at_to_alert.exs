defmodule Alerts.Repo.Migrations.AddCreatedAtToAlert do
  use Ecto.Migration

  def change do
    alter table(:alert) do
      add :created_at, :naive_datetime
    end
  end
end

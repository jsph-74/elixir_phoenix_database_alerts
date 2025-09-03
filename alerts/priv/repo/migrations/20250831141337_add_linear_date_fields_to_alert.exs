defmodule Alerts.Repo.Migrations.AddLinearDateFieldsToAlert do
  use Ecto.Migration

  def change do
    alter table(:alert) do
      add :last_edited, :naive_datetime
      add :last_status_change, :naive_datetime
    end
  end
end

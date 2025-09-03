defmodule Alerts.Repo.Migrations.ExpandQueryField do
  use Ecto.Migration

  def change do
    alter table(:alert) do
      modify :query, :text
    end
  end
end

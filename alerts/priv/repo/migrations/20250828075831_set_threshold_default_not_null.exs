defmodule Alerts.Repo.Migrations.SetThresholdDefaultNotNull do
  use Ecto.Migration

  def change do
    # First, update any existing NULL threshold values to 0
    execute "UPDATE alert SET threshold = 0 WHERE threshold IS NULL", "UPDATE alert SET threshold = NULL WHERE threshold = 0"
    
    # Then alter the column to set default and add NOT NULL constraint
    alter table(:alert) do
      modify :threshold, :integer, default: 0, null: false
    end
  end
end

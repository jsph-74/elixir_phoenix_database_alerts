defmodule Alerts.Repo.Migrations.DropAppSecurityTable do
  use Ecto.Migration

  def change do
    drop table(:app_security)
  end
end
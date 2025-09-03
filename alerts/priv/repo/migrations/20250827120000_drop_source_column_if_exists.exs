defmodule Alerts.Repo.Migrations.DropSourceColumnIfExists do
  use Ecto.Migration

  def up do
    # Check if the source column exists and drop it if it does
    if column_exists?(:alert, :source) do
      alter table(:alert) do
        remove :source
      end
    end
  end

  def down do
    # Don't add the column back in rollback - we want it gone
    :ok
  end

  defp column_exists?(table, column) do
    query = """
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = $1 AND column_name = $2 AND table_schema = 'public'
    """
    
    result = Ecto.Adapters.SQL.query!(Alerts.Repo, query, [to_string(table), to_string(column)])
    length(result.rows) > 0
  end
end
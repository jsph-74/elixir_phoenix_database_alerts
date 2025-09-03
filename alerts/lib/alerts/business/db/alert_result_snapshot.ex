defmodule Alerts.Business.DB.AlertResultSnapshot do
  use Ecto.Schema
  import Ecto.Changeset
  alias Alerts.Business.DB.Alert

  @primary_key {:id, :id, autogenerate: true}
  schema "alert_result_snapshots" do
    field :executed_at, :utc_datetime
    field :result_hash, :string
    field :row_count, :integer
    field :total_rows, :integer
    field :is_truncated, :boolean, default: false
    field :status, :string
    field :error_message, :string
    field :csv_data, :string, default: ""

    belongs_to :alert, Alert, foreign_key: :alert_id

    timestamps()
  end

  @required_fields [:alert_id, :executed_at, :result_hash, :row_count, :total_rows, :status]
  @optional_fields [:is_truncated, :error_message, :csv_data]

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ["good", "bad", "under_threshold", "broken"])
    |> foreign_key_constraint(:alert_id)
    |> unique_constraint([:alert_id, :result_hash], 
        name: :alert_result_snapshots_alert_id_result_hash_index,
        message: "Results already stored for this alert")
  end

  def new_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
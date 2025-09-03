defmodule Alerts.Business.DB.Alert do
  use Ecto.Schema

  require Ecto.Query
  require Ecto.Query.API

  alias Ecto.Query, as: Q
  alias Ecto.Changeset, as: C
  alias Alerts.Business.DB.DataSource

  require Crontab.CronExpression.Parser

  @primary_key {:id, :id, autogenerate: true}
  schema "alert" do
    field(:context, :string)
    field(:name, :string)
    field(:query, :string)

    field(:description, :string)

    field(:last_run, :naive_datetime)
    field(:created_at, :naive_datetime)
    field(:last_edited, :naive_datetime)
    field(:last_status_change, :naive_datetime)

    timestamps()

    field(:results_size, :integer)
    field(:threshold, :integer, default: 0)

    field(:schedule, :string)

    field(:status, :string)

    # source field removed - use data_source association instead
    field(:data_source_id, :id)


    # Associations
    belongs_to(:data_source, DataSource, define_field: false, foreign_key: :data_source_id)

    # New history versioning fields
    field(:alert_public_id, Ecto.UUID)
    field(:lifecycle_status, :string, default: "current")
  end

  defp nowNaive(), do: Timex.now() |> DateTime.truncate(:second) |> Timex.to_naive_datetime()

  defp atomize(map) do
    for {key, val} <- map, into: %{} do
      case is_atom(key) do
        false -> {String.to_atom(key), val}
        true -> {key, val}
      end
    end
  end

  def contexts() do
    __MODULE__
    |> Q.where([alert], alert.lifecycle_status == "current")
    |> Q.select([alert], [alert.context])
    |> Q.distinct(true)
  end

  def scheduled_alerts do
    __MODULE__
    |> Q.where([alert], not is_nil(alert.schedule))
    |> Q.where([alert], alert.lifecycle_status == "current")
    |> Q.order_by(desc: :name)
  end

  def alerts_in_context(context, order) do
    __MODULE__
    |> Q.where([alert], alert.context == ^context)
    |> Q.where([alert], alert.lifecycle_status == "current")
    |> Q.order_by(asc: ^order)
  end

  def get_current_alert_by_history_id(history_id) do
    __MODULE__
    |> Q.where([alert], alert.alert_public_id == ^history_id)
    |> Q.where([alert], alert.lifecycle_status == "current")
  end

  def get_alert_history_by_history_id(history_id) do
    __MODULE__
    |> Q.where([alert], alert.alert_public_id == ^history_id)
    |> Q.order_by([
      # Current status first, then by newest insertion time
      desc: fragment("CASE WHEN lifecycle_status = 'current' THEN 1 ELSE 0 END"),
      desc: :inserted_at
    ])
  end

  def run_changeset(%__MODULE__{} = alert, params_x) do
    params = atomize(params_x)
    current_time = nowNaive()

    changeset =
      alert
      |> C.cast(params, [:results_size])
      |> C.change(last_run: current_time)

    new_status = get_status(changeset.data |> Map.merge(changeset.changes))
    old_status = alert.status
    
    # Update last_status_change if:
    # 1. Status actually changed, OR
    # 2. force_status_change is true (indicating results changed even if status didn't)
    should_update_status_change = (new_status != old_status) || params[:force_status_change] == true
    
    changeset = if should_update_status_change do
      C.change(changeset, last_status_change: current_time)
    else
      changeset
    end

    changeset
    |> C.change(status: new_status)
    |> C.validate_required([:last_run, :results_size])
  end

  def new_changeset(), do: new_changeset(%__MODULE__{}, %{context: ""})
  def new_changeset(params), do: new_changeset(%__MODULE__{}, params)

  def initial_changeset() do
    %__MODULE__{}
    |> C.cast(%{context: ""}, [:context])
    |> C.change(alert_public_id: Ecto.UUID.generate())
    |> C.change(lifecycle_status: "current")
  end

  def new_changeset(%__MODULE__{} = alert, params_x) do
    params = atomize(params_x)

    current_time = nowNaive()
    alert
    |> C.cast(params, [:name, :description, :schedule, :threshold, :data_source_id])
    |> C.change(context: params[:context])
    |> C.change(created_at: current_time)
    |> C.change(last_edited: current_time)
    |> C.change(status: get_status(:new))
    |> C.change(alert_public_id: Ecto.UUID.generate())
    |> C.change(lifecycle_status: "current")
    |> C.force_change(:query, params[:query])
    |> C.validate_required([:name, :description, :context, :query, :data_source_id])
    |> validate(:query, data_source_id: params[:data_source_id])
    |> validate(:schedule)
  end

  def modify_changeset(%__MODULE__{} = alert),
    do: modify_changeset(alert, alert |> Map.from_struct())

  def modify_changeset(%__MODULE__{} = alert, params_x) do
    params = atomize(params_x)

    alert
    |> C.cast(params, [:name, :description, :context, :schedule, :threshold, :data_source_id, :lifecycle_status, :alert_public_id, :created_at, :last_edited, :last_run, :last_status_change])
    |> C.change(context: params[:context] || alert.context)
    |> C.change(created_at: params[:created_at] || alert.created_at)
    |> C.change(last_edited: params[:last_edited] || nowNaive())
    |> C.change(last_run: params[:last_run] || alert.last_run)
    |> C.change(last_status_change: params[:last_status_change] || alert.last_status_change)
    |> C.change(status: get_status(:updated))
    |> C.change(lifecycle_status: params[:lifecycle_status] || "current")
    |> C.change(alert_public_id: params[:alert_public_id] || alert.alert_public_id)
    |> C.force_change(:query, params[:query] || alert.query)
    |> C.validate_required([:name, :description, :context, :query, :data_source_id, :alert_public_id, :lifecycle_status])
    |> validate(:query, data_source_id: params[:data_source_id] || alert.data_source_id)
    |> validate(:schedule)
  end

  def validate(changeset, field, options \\ [])

  def validate(changeset, :query, _options) do
    changeset
    |> C.validate_required([:query])
    |> C.validate_length(:query, min: 1, message: "Query cannot be empty")
  end

  def validate(changeset, :schedule, _options) do
    changeset
    |> C.validate_change(:schedule, fn _, schedule ->
      case Crontab.CronExpression.Parser.parse(schedule) do
        {:error, text} -> [{:schedule, "Your scheduler format is wrong: " <> text}]
        _ -> []
      end
    end)
  end

  def get_status(:new), do: "never run"
  def get_status(:updated), do: "needs refreshing"
  def get_status(%{results_size: -1}), do: "broken"
  def get_status(%{results_size: 0}), do: "good"
  def get_status(%{results_size: s, threshold: 0}) when s > 0, do: "bad"
  def get_status(%{results_size: s, threshold: t}) when s >= t and t > 0, do: "bad"
  def get_status(%{results_size: s, threshold: t}) when s < t and t > 0, do: "under_threshold"
  def get_status(%{results_size: s}) when s > 0, do: "bad"

  @doc """
  Mark all alerts with the given alert_public_id as old status
  """
  def mark_alerts_as_old(alert_public_id) do
    import Ecto.Query
    from(a in __MODULE__, where: a.alert_public_id == ^alert_public_id)
    |> Alerts.Repo.update_all(set: [lifecycle_status: "old"])
  end

  @doc """
  Changeset for updating only lifecycle_status - doesn't touch business date fields
  """
  def lifecycle_changeset(%__MODULE__{} = alert, lifecycle_status) do
    alert
    |> C.change(lifecycle_status: lifecycle_status)
    |> C.validate_required([:lifecycle_status])
  end
end

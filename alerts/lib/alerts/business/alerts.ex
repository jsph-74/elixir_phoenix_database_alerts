defmodule Alerts.Business.Alerts do
  @moduledoc """
  Business logic for managing alerts including CRUD operations,
  version management, and job scheduling integration.
  """

  alias Alerts.Repo
  alias Alerts.Business.DB
  alias Alerts.Business.Odbc
  alias Alerts.Business.Jobs
  alias Alerts.Business.Helpers
  alias Alerts.Business.QueryValidator
  alias Crontab.CronExpression.Parser

  require Logger

  # ============================================================================
  # PUBLIC API - Query Functions
  # ============================================================================

  def contexts(),
    do: DB.Alert.contexts() |> Repo.all() |> Enum.reduce([], &(&1 ++ &2))

  def alerts_in_context(context, order),
    do: context |> DB.Alert.alerts_in_context(order) |> Repo.all() |> Repo.preload(:data_source)

  def get!(%DB.Alert{} = alert),
    do: get!(alert.id)

  def get!(alert_id),
    do: DB.Alert |> Repo.get!(alert_id)

  def get_by_uuid!(alert_public_id) do
    DB.Alert.get_current_alert_by_history_id(alert_public_id)
    |> Repo.one!()
    |> Repo.preload(:data_source)
  end

  def get_alert_history(alert_public_id) do
    DB.Alert.get_alert_history_by_history_id(alert_public_id)
    |> Repo.all()
    |> Repo.preload(:data_source)
  end

  # ============================================================================
  # PUBLIC API - CRUD Operations
  # ============================================================================

  def delete(alert_id) do
    alert = get!(alert_id)
    do_delete(alert)
  end

  def delete_by_uuid(alert_public_id) do
    alert = get_by_uuid!(alert_public_id)
    do_delete(alert)
  end

  defp do_delete(alert) do
    # Mark current alert as old - only touch lifecycle_status
    alert
    |> DB.Alert.lifecycle_changeset("old")
    |> Repo.update!()

    # Create new version marked as deleted
    deleted_alert = %DB.Alert{}
    |> struct(Map.from_struct(alert))
    |> Map.put(:id, nil)
    |> DB.Alert.modify_changeset(%{lifecycle_status: "deleted"})
    |> Repo.insert!()

    Jobs.delete_alert_job(deleted_alert)
    deleted_alert
  end

  # ============================================================================
  # PUBLIC API - Changeset Functions
  # ============================================================================

  def change(),
    do: DB.Alert.initial_changeset()

  def change(%DB.Alert{} = alert),
    do: DB.Alert.modify_changeset(alert)


  def reboot_all_jobs() do
    Alerts.Scheduler.delete_all_jobs()

    DB.Alert.scheduled_alerts()
    |> Repo.all()
    |> Enum.map(&Jobs.save_alert_job/1)
  end

  def create(params) do
    # Trim query before saving
    trimmed_params = Helpers.trim_query_params(params)

    # Business validation: M2H context (interactive form submission)
    query = trimmed_params["query"] || trimmed_params[:query]
    data_source_id = trimmed_params["data_source_id"] || trimmed_params[:data_source_id]

    validation_result = QueryValidator.validate_query_and_connection(query, data_source_id, :interactive)

    # Create changeset and add business validation errors
    changeset =
      trimmed_params
      |> DB.Alert.new_changeset()
      |> QueryValidator.add_validation_errors(validation_result)

    case Repo.insert(changeset) do
      {:ok, inserted} ->
        inserted
        |> Jobs.save_alert_job()

        {:ok, inserted}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(%DB.Alert{} = alert, params) do
    # Trim query before saving
    trimmed_params = Helpers.trim_query_params(params)

    # Check if any meaningful changes were made
    meaningful_fields = [:name, :description, :context, :query, :data_source_id, :threshold, :schedule]
    if Helpers.has_meaningful_changes?(alert, trimmed_params, meaningful_fields) do
      # Prepare new alert version FIRST (don't insert yet)
      # Start with fresh struct to avoid any timestamp carryover
      new_alert = %DB.Alert{
        context: alert.context,
        name: alert.name,
        query: alert.query,
        description: alert.description,
        results_size: alert.results_size,
        threshold: alert.threshold,
        schedule: alert.schedule,
        status: alert.status,
        data_source_id: alert.data_source_id,
        alert_public_id: alert.alert_public_id,
        lifecycle_status: alert.lifecycle_status,
        last_run: alert.last_run,
        created_at: alert.created_at,
        last_status_change: alert.last_status_change
      }

      # Merge the params with preserved fields from old version
      update_params = trimmed_params
      |> Map.put(:alert_public_id, alert.alert_public_id)
      |> Map.put(:created_at, alert.created_at)
      |> Map.put(:last_run, alert.last_run)
      |> Map.put(:last_status_change, alert.last_status_change)
      # last_edited will be set to now() in modify_changeset

      # Business validation: M2H context (interactive form submission)
      query = update_params["query"] || update_params[:query] || alert.query
      data_source_id = update_params["data_source_id"] || update_params[:data_source_id] || alert.data_source_id

      validation_result = QueryValidator.validate_query_and_connection(query, data_source_id, :interactive)

      # Create changeset with business validation
      new_changeset =
        new_alert
        |> DB.Alert.modify_changeset(update_params)
        |> QueryValidator.add_validation_errors(validation_result)

      # Insert AFTER validation
      case Repo.insert(new_changeset) do
        {:ok, updated} ->
          # Only NOW that we know the new alert was created successfully:
          # 1. Delete the quantum job
          # 2. Mark old alert as "old"
          # 3. Set up new job and folder
          Jobs.delete_alert_job(alert)

          # TODO: Add query to ensure only one current alert per history_id

          alert
          |> DB.Alert.lifecycle_changeset("old")
          |> Repo.update!()

          updated
          |> Jobs.save_alert_job()

          {:ok, updated}

        {:error, _changeset} = error ->
          # If new alert creation fails (SQL validation, etc.), nothing has been modified
          # The original alert remains current and active
          error
      end
    else
      # No meaningful changes detected, return the existing alert unchanged
      {:ok, alert}
    end
  end

  def update_by_uuid(alert_public_id, params) do
    alert = get_by_uuid!(alert_public_id)
    update(alert, params)
  end

  # ============================================================================
  # PUBLIC API - Job Management
  # ============================================================================

  def get_all_alert_jobs_config do
    DB.Alert.scheduled_alerts()
    |> Repo.all()
    |> Enum.reduce([], fn alert, acc ->
      case alert.schedule |> Parser.parse() do
        {:error, text} ->
          Logger.error("Error! #{alert.id} #{alert.schedule} #{text}")
          acc

        _ ->
          acc ++ [Jobs.get_alert_quantum_config(alert)]
      end
    end)
  end

  # ============================================================================
  # PUBLIC API - Execution Functions
  # ============================================================================

  def run({:ok, %DB.Alert{} = alert}),
    do: run(alert.id)

  def run(alert_id) do
    alert = get!(alert_id)
    results = alert.query |> Odbc.run_query_by_data_source_id(alert.data_source_id)

    {results, results |> store_results(alert)}
  end

  def run_by_history_id(alert_public_id) do
    alert = DB.Alert.get_current_alert_by_history_id(alert_public_id) |> Repo.one!()
    results = alert.query |> Odbc.run_query_by_data_source_id(alert.data_source_id)

    {results, results |> store_results(alert)}
  end

  # Helper function for testing - allows mocking results
  def run_with_results(alert_id, results) do
    alert = get!(alert_id)
    results |> store_results(alert)
  end

  def get_csv(%{rows: nil}), do: nil
  def get_csv(%{columns: c, rows: r}), do: CSV.encode([c | r]) |> Enum.to_list() |> to_string()

  def get_num_rows(%{rows: nil}), do: -1
  def get_num_rows(%{rows: _rows, num_rows: num_rows}), do: num_rows

  def get_total_rows(%{total_rows: total_rows}), do: total_rows
  def get_total_rows(%{rows: _rows, num_rows: num_rows}), do: num_rows  # Fallback for old results
  def get_total_rows(_), do: -1

  def is_truncated?(%{is_truncated: is_truncated}), do: is_truncated
  def is_truncated?(_), do: false  # Fallback for old results



  def store_results({:ok, results}, %DB.Alert{} = alert) do
    # Determine the new status first
    total_rows = get_total_rows(results)
    new_status = DB.Alert.get_status(%{results_size: total_rows, threshold: alert.threshold})
    
    # Skip snapshot creation for dummy statuses - they don't represent real monitoring data
    unless new_status in ["never run", "needs refreshing"] do
      # Check if results changed (for last_status_change logic)
      csv_data = get_csv(results)
      new_hash = Alerts.Business.AlertResultsHistory.calculate_result_hash(csv_data)
      
      # Get the latest snapshot to compare
      latest_snapshot = case Alerts.Business.AlertResultsHistory.get_result_history(alert.id, limit: 1) do
        [snapshot] -> snapshot
        [] -> nil
      end
      
      # Determine if we should update last_status_change
      force_status_change = case latest_snapshot do
        nil -> true  # First real run
        snapshot -> new_hash != snapshot.result_hash  # Results changed
      end

      # Store historical snapshot (write-only log) - only for real monitoring results
      Alerts.Business.AlertResultsHistory.store_result_snapshot(alert, results)

      # Update alert with new run info
      update_params = %{
        "results_size" => total_rows,
        "force_status_change" => force_status_change
      }
      
      alert
      |> DB.Alert.run_changeset(update_params)
      |> Repo.update!()
    else
      # For dummy statuses, just update the alert without creating snapshots
      alert
      |> DB.Alert.run_changeset(%{"results_size" => total_rows})
      |> Repo.update!()
    end
  end

  def store_results({:error, error_message}, %DB.Alert{} = alert) do
    # Store error snapshot (only if error/status changed)
    Alerts.Business.AlertResultsHistory.store_result_snapshot(alert, {:error, error_message})

    # Just update the existing alert with error status - NEVER create new versions on run errors
    # Always update last_status_change for errors since they represent meaningful changes
    alert
    |> DB.Alert.run_changeset(%{"results_size" => -1, "force_status_change" => true})
    |> Repo.update!()
  end

  def store_results(_, %DB.Alert{} = alert) do
    # Fallback for unexpected result types
    alert
    |> DB.Alert.run_changeset(%{"results_size" => -1})
    |> Repo.update!()
  end

end

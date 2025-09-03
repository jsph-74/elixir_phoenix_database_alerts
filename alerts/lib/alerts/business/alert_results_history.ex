defmodule Alerts.Business.AlertResultsHistory do
  @moduledoc """
  Business logic for managing alert results history with change detection.
  Only stores snapshots when results actually change to avoid redundant storage.
  """

  alias Alerts.Repo
  alias Alerts.Business.DB.{Alert, AlertResultSnapshot}
  alias Alerts.Business.{DB, Alerts}
  import Ecto.Query
  require Logger

  @doc """
  Stores a result snapshot only if results have changed from the last snapshot.

  Returns:
  - {:ok, snapshot} when new snapshot is created
  - {:no_change, last_snapshot} when results are identical to last snapshot
  """
  def store_result_snapshot(%Alert{} = alert, results) when is_map(results) do
    csv_data = Alerts.get_csv(results)
    result_hash = calculate_result_hash(csv_data)

    case get_latest_snapshot(alert.id) do
      nil ->
        # First snapshot for this alert
        create_snapshot(alert, results, csv_data, result_hash)

      last_snapshot ->
        # Compare new status against the last snapshot status, not current alert status
        # (alert.status might be stale if threshold was recently updated)
        new_status = determine_status(alert, results)
        last_status = last_snapshot.status

        # Store snapshot if status changed OR results changed (different hash)
        # This aligns with the linear date model where last_status_change updates for both cases
        status_changed = last_status == "never run" or last_status != new_status
        results_changed = result_hash != last_snapshot.result_hash
        
        if status_changed or results_changed do
          reason = cond do
            status_changed -> "status changed from #{last_status} to #{new_status}"
            results_changed -> "results changed (same status: #{new_status})"
            true -> "unknown"
          end
          Logger.debug("Alert #{alert.id} #{reason}, creating snapshot")
          create_snapshot(alert, results, csv_data, result_hash)
        else
          Logger.debug("Alert #{alert.id} status and results unchanged (#{last_status}), skipping snapshot")
          {:no_change, last_snapshot}
        end
    end
  end

  def store_result_snapshot(%Alert{} = alert, {:error, error_message}) do
    # Only store error snapshots if the error changed from last snapshot
    error_hash = calculate_result_hash("ERROR: #{error_message}")

    case get_latest_snapshot(alert.id) do
      nil ->
        # First error snapshot for this alert
        create_error_snapshot(alert, error_message, error_hash)

      last_snapshot ->
        # For errors, also check if status changed (broken -> broken with different error is worth storing)
        if last_snapshot.result_hash == error_hash and last_snapshot.status == "broken" do
          Logger.debug("Alert #{alert.id} error unchanged, skipping snapshot")
          {:no_change, last_snapshot}
        else
          Logger.debug("Alert #{alert.id} error changed or status changed, creating new snapshot")
          create_error_snapshot(alert, error_message, error_hash)
        end
    end
  end

  @doc """
  Gets result history for an alert, ordered by execution time (newest first).
  """
  def get_result_history(alert_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(s in AlertResultSnapshot,
      where: s.alert_id == ^alert_id,
      order_by: [desc: s.executed_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets complete result history for all versions of an alert by alert_public_id.
  This ensures the timeline shows the complete log across all alert versions.
  """
  def get_complete_result_history(alert_public_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(s in AlertResultSnapshot,
      join: a in Alert, on: s.alert_id == a.id,
      where: a.alert_public_id == ^alert_public_id,
      order_by: [desc: s.executed_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets a specific result snapshot by ID.
  """
  def get_result_history_by_id(snapshot_id) do
    Repo.get(AlertResultSnapshot, snapshot_id)
  end

  @doc """
  Gets time series data for charting (timestamp + row count).
  """
  def get_time_series_data(alert_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(s in AlertResultSnapshot,
      where: s.alert_id == ^alert_id and s.executed_at >= ^cutoff_date,
      order_by: [asc: s.executed_at],
      select: %{
        timestamp: s.executed_at,
        row_count: s.total_rows,  # Use total_rows for accurate counts
        status: s.status
      }
    )
    |> Repo.all()
  end


  @doc """
  Calculates a hash for result data to detect changes.
  """
  def calculate_result_hash(csv_data) when is_binary(csv_data) do
    :crypto.hash(:sha256, csv_data)
    |> Base.encode16(case: :lower)
  end

  # Private helper functions

  defp get_latest_snapshot(alert_id) do
    from(s in AlertResultSnapshot,
      where: s.alert_id == ^alert_id,
      order_by: [desc: s.executed_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp create_snapshot(%Alert{} = alert, results, csv_data, result_hash) do
    status = determine_status(alert, results)

    attrs = %{
      alert_id: alert.id,
      executed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      result_hash: result_hash,
      row_count: Alerts.get_num_rows(results),
      total_rows: Alerts.get_total_rows(results),
      is_truncated: Alerts.is_truncated?(results),
      status: status,
      error_message: nil,
      csv_data: csv_data
    }

    case AlertResultSnapshot.new_changeset(attrs) |> Repo.insert() do
      {:ok, snapshot} ->
        Logger.info("Stored new snapshot for alert #{alert.id}, status: #{status}")
        {:ok, snapshot}

      {:error, changeset} ->
        Logger.error("Failed to store snapshot: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp create_error_snapshot(%Alert{} = alert, error_message, error_hash) do
    attrs = %{
      alert_id: alert.id,
      executed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      result_hash: error_hash,
      row_count: -1,
      total_rows: -1,
      is_truncated: false,
      status: "broken",
      error_message: error_message,
      csv_data: ""
    }

    case AlertResultSnapshot.new_changeset(attrs) |> Repo.insert() do
      {:ok, snapshot} ->
        Logger.info("Stored error snapshot for alert #{alert.id}")
        {:ok, snapshot}

      {:error, changeset} ->
        Logger.error("Failed to store error snapshot: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp determine_status(%Alert{} = alert, results) do
    total_rows = Alerts.get_total_rows(results)
    # Use the same status calculation logic as Alert.get_status/1
    DB.Alert.get_status(%{results_size: total_rows, threshold: alert.threshold})
  end

end

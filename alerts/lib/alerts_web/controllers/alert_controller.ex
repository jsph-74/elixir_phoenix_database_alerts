defmodule AlertsWeb.AlertController do
  use AlertsWeb, :controller

  alias Alerts.Business.DataSources
  alias Alerts.Business.AlertResultsHistory
  alias Alerts.Scheduler

  def index(conn, params) do
    available_contexts = Alerts.Business.Alerts.contexts()
    requested_context = params["context"]
    
    # Check if we need to redirect to a valid context
    cond do
      # Requested context doesn't exist and we have alternatives - redirect
      requested_context != nil and requested_context not in available_contexts and available_contexts != [] ->
        first_available = Enum.at(available_contexts, 0)
        redirect(conn, to: ~p"/alerts?context=#{first_available}")
      
      # Normal flow - determine context and render
      true ->
        context = if requested_context in available_contexts do
          requested_context
        else
          Enum.at(available_contexts, 0) || ""
        end
        
        alerts = Alerts.Business.Alerts.alerts_in_context(context, String.to_atom(params["order"] || "name"))

        render(
          conn,
          "index.html",
          available_contexts:
            ([context] ++ available_contexts)
            |> Enum.uniq()
            |> Enum.sort_by(&:string.lowercase/1, &</2),
          context: context,
          alerts: alerts
        )
    end
  end

  def reboot(conn, params) do
    number_of_jobs = Scheduler.reboot_all_jobs() |> Enum.count()

    conn
    |> put_flash(:info, "#{number_of_jobs} jobs were rebooted")
    |> redirect(to: ~p"/alerts?context=#{params["context"]}")
  end

  def run_all(conn, params) do
    context = params["context"] || ""
    alerts = Alerts.Business.Alerts.alerts_in_context(context, :name)

    results = Enum.map(alerts, fn alert ->
      {result, _updated_alert} = Alerts.Business.Alerts.run(alert.id)
      {alert.name, result}
    end)

    {successful_count, failed_results} = Enum.reduce(results, {0, []}, fn {name, result}, {success_count, failures} ->
      case result do
        {:error, message} -> {success_count, [{name, message} | failures]}
        _ -> {success_count + 1, failures}
      end
    end)

    flash_message = case failed_results do
      [] -> "Successfully ran all #{successful_count} alerts in #{context} context"
      failures ->
        failure_names = failures |> Enum.map(fn {name, _} -> name end) |> Enum.join(", ")
        "Ran #{successful_count} alerts successfully. Failed: #{failure_names}"
    end

    flash_level = if length(failed_results) == 0, do: :info, else: :error

    conn
    |> put_flash(flash_level, flash_message)
    |> redirect(to: ~p"/alerts?context=#{context}")
  end

  def view(conn, %{"uuid" => alert_uuid}) do
    try do
      alert = Alerts.Business.Alerts.get_by_uuid!(alert_uuid)
      alert_history = Alerts.Business.Alerts.get_alert_history(alert.alert_public_id)
      results_history = AlertResultsHistory.get_complete_result_history(alert.alert_public_id, limit: 100)

      # Create unified timeline
      unified_timeline = create_unified_timeline(alert_history, results_history)

      render(conn, "view.html", alert: alert, query_history: alert_history, unified_timeline: unified_timeline)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def new(conn, _params) do
    data_sources = DataSources.list_data_sources()
    render(conn, "new.html", alert_changeset: Alerts.Business.Alerts.change(), data_sources: data_sources)
  end

  def create(conn, %{"alert" => params}) do
    data_sources = DataSources.list_data_sources()

    params
    |> Alerts.Business.Alerts.create()
    |> case do
      {:ok, alert} ->
        conn
        |> put_flash(:info, "ok")
        |> redirect(to: ~p"/alerts/#{alert.alert_public_id}")

      {:error, %Ecto.Changeset{} = alert_changeset} ->
        render(conn, "new.html", alert_changeset: alert_changeset, data_sources: data_sources)
    end
  end

  def edit(conn, %{"uuid" => alert_uuid}) do
    try do
      alert = Alerts.Business.Alerts.get_by_uuid!(alert_uuid)
      data_sources = DataSources.list_data_sources()
      render(conn, "edit.html", alert: alert, alert_changeset: Alerts.Business.Alerts.change(alert), data_sources: data_sources)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def update(conn, %{"alert" => params, "uuid" => alert_uuid}) do
    try do
      alert = Alerts.Business.Alerts.get_by_uuid!(alert_uuid)
      data_sources = DataSources.list_data_sources()

      alert_uuid
      |> Alerts.Business.Alerts.update_by_uuid(params)
      |> case do
        {:ok, updated_alert} ->
          conn
          |> put_flash(:info, "ok")
          |> redirect(to: ~p"/alerts/#{updated_alert.alert_public_id}")

        {:error, %Ecto.Changeset{} = alert_changeset} ->
          render(conn, "edit.html", alert_changeset: alert_changeset, alert: alert, data_sources: data_sources)
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def delete(conn, %{"uuid" => alert_uuid}) do
    try do
      # Get the alert before deleting to access its context
      alert = Alerts.Business.Alerts.get_by_uuid!(alert_uuid)

      # Delete the alert (creates new version marked as deleted)
      _deleted_alert = Alerts.Business.Alerts.delete_by_uuid(alert_uuid)

      conn
      |> put_flash(:info, "Alert deleted successfully.")
      |> redirect(to: ~p"/alerts?context=#{alert.context}")
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end


  def run(conn, params = %{"uuid" => alert_uuid}) do
    try do
      alert = Alerts.Business.Alerts.get_by_uuid!(alert_uuid)
      {results, alert} = Alerts.Business.Alerts.run(alert.id)

      {level, msg} =
        case results do
          {:error, message} ->
            {:error,
             [
               "Alert ",
               Phoenix.HTML.raw("<strong>#{alert.name}</strong>"),
               " is ",
               AlertsWeb.AlertHTML.render_status(alert),
               Phoenix.HTML.raw("<br>"),
               Phoenix.HTML.raw("<br>"),
               "Error message is ",
               message
             ]}

          _ ->
            {:info,
             [
               "Alert ",
               Phoenix.HTML.raw("<strong>#{alert.name}</strong>"),
               " run succesfully",
               Phoenix.HTML.raw("<br>"),
               Phoenix.HTML.raw("<br>"),
               "Alert status is ",
               AlertsWeb.AlertHTML.render_status(alert)
             ]}
        end

      case params["follow"] do
        nil ->
          conn
          |> put_flash(level, msg)
          |> redirect(to: ~p"/alerts?context=#{alert.context}")

        _ ->
          conn
          |> put_flash(level, msg)
          |> redirect(to: ~p"/alerts/#{alert.alert_public_id}")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def csv(conn, %{"uuid" => alert_uuid}) do
    try do
      alert = Alerts.Business.Alerts.get_by_uuid!(alert_uuid)

      # Get latest snapshot from database
      case AlertResultsHistory.get_result_history(alert.id, limit: 1) do
        [latest_snapshot] ->
          filename = generate_csv_filename(alert, latest_snapshot.executed_at)

          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_resp(200, latest_snapshot.csv_data)

        [] ->
          conn
          |> put_status(:not_found)
          |> put_view(AlertsWeb.ErrorHTML)
          |> render(:"404")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def csv_snapshot(conn, %{"id" => snapshot_id}) do
    try do
      case AlertResultsHistory.get_result_history_by_id(snapshot_id) do
        snapshot when not is_nil(snapshot) ->
          alert = Alerts.Business.Alerts.get!(snapshot.alert_id)
          filename = generate_csv_filename(alert, snapshot.executed_at)

          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_resp(200, snapshot.csv_data)

        nil ->
          conn
          |> put_status(:not_found)
          |> put_view(AlertsWeb.ErrorHTML)
          |> render(:"404")
      end
    rescue
      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  defp generate_csv_filename(alert, executed_at) do
    date_suffix = Calendar.strftime(executed_at, "%Y%m%d_%H%M%S")
    "#{alert.id}-#{Slugger.slugify_downcase(alert.name)}-#{Mix.env()}-#{date_suffix}.csv"
  end

  # Create unified timeline combining alert changes and results changes
  def create_unified_timeline(alert_history, results_history) do
    # Build simple list of {alert, result_or_nil, timestamp} tuples
    timeline_tuples = build_timeline_tuples(alert_history, results_history)
    
    # Build timeline events with diff logic
    timeline_tuples
    |> Enum.with_index()
    |> Enum.map(fn {{alert, result, timestamp}, index} ->
      # Since timeline is newest first, the LAST config event is the creation
      is_last_event = index == length(timeline_tuples) - 1
      is_config_event = result == nil
      should_show_as_creation = is_config_event && is_last_event
      
      # Find appropriate previous item for diffing
      previous_item = find_previous_for_diff(timeline_tuples, index, result != nil)
      
      # Build the timeline event
      build_timeline_event(alert, result, timestamp, previous_item, index == 0, should_show_as_creation)
    end)
  end
  
  # Build unified timeline: UNION of alert events and result events, ordered by time DESC
  defp build_timeline_tuples(alert_history, results_history) do
    
    # 1. Create alert events: {type: :alert, alert: alert, result: nil, timestamp: last_edited}
    alert_events = alert_history
    |> Enum.map(fn alert ->
      # Always use last_edited for alert events (when the alert was modified)
      %{type: :alert, alert: alert, result: nil, timestamp: alert.last_edited}
    end)
    
    # 2. Create result events: {type: :result, alert: linked_alert, result: result, timestamp: inserted_at}
    result_events = results_history
    |> Enum.reject(fn result -> result.status == "needs refreshing" end)
    |> Enum.map(fn result ->
      # Find the alert that this result belongs to
      linked_alert = Enum.find(alert_history, fn alert -> alert.id == result.alert_id end)
      # Use inserted_at for result events (when the snapshot was stored)
      timestamp = case result.inserted_at do
        %DateTime{} = dt -> DateTime.to_naive(dt)
        %NaiveDateTime{} = ndt -> ndt
        _ -> result.inserted_at
      end
      %{type: :result, alert: linked_alert, result: result, timestamp: timestamp}
    end)
    |> Enum.reject(fn event -> event.alert == nil end)
    
    # 3. UNION: Combine all events and sort by timestamp (newest first - descending)
    all_events = (alert_events ++ result_events)
    |> Enum.sort_by(fn event -> 
      event.timestamp |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:microsecond) 
    end, :desc)
    
    # 4. Convert back to tuple format: {alert, result, timestamp}
    timeline_tuples = all_events
    |> Enum.map(fn event ->
      {event.alert, event.result, event.timestamp}
    end)
    
    timeline_tuples
  end
  
  # Find the appropriate previous item for diffing
  defp find_previous_for_diff(timeline_tuples, current_index, is_result_event) do
    if is_result_event do
      # For result events, find previous result (skip config events)
      timeline_tuples
      |> Enum.drop(current_index + 1)
      |> Enum.find(fn {_alert, result, _timestamp} -> result != nil end)
    else
      # For config events, find previous config event (skip result events)  
      timeline_tuples
      |> Enum.drop(current_index + 1)
      |> Enum.find(fn {_alert, result, _timestamp} -> result == nil end)
    end
  end
  
  defp build_timeline_event(alert, result, timestamp, previous_pair, is_most_recent, is_first_alert) do
    case {result, previous_pair} do
      # Config change event: (alert, nil)
      {nil, _} ->
        # Use the should_show_as_creation flag to determine creation vs update
        is_creation = is_first_alert
        
        %{
          type: :config_change,
          timestamp: timestamp,
          icon: "🔧",
          title: if(is_creation, do: "Alert created", else: "Alert updated"),
          summary: get_config_change_summary(alert),
          data: alert,
          previous_data: extract_previous_alert(previous_pair),
          diff_content: build_diff_content(extract_tuple_3(previous_pair), {alert, nil}),
          is_current_config: is_most_recent,
          is_current: is_most_recent,
          sortable_time: timestamp |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:microsecond)
        }
        
      # Result event: (alert, result) 
      {result, _} ->
        status_display = case result.status do
          "under_threshold" -> "under threshold"
          "needs_refreshing" -> "needs refreshing"
          _ -> result.status
        end
        
        %{
          type: :result_change,
          timestamp: timestamp,
          icon: case result.status do
            "good" -> "✅"
            "bad" -> "❌" 
            "under_threshold" -> "⚠️"
            "broken" -> "🔴"
            "needs_refreshing" -> "🔄"
            _ -> "📊"
          end,
          title: "Alert status: #{status_display}",
          summary: get_result_change_summary(result),
          data: result,
          previous_data: extract_previous_result(previous_pair),
          diff_content: build_diff_content(extract_tuple_3(previous_pair), {alert, result}),
          is_current: is_most_recent,
          sortable_time: timestamp |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:microsecond)
        }
    end
  end
  
  defp extract_previous_alert(nil), do: nil
  defp extract_previous_alert({alert, _result, _timestamp}), do: alert
  defp extract_previous_alert({alert, _result, _timestamp, _is_first}), do: alert
  
  defp extract_previous_result(nil), do: nil  
  defp extract_previous_result({_alert, result, _timestamp}), do: result
  defp extract_previous_result({_alert, result, _timestamp, _is_first}), do: result
  
  defp extract_tuple_3(nil), do: nil
  defp extract_tuple_3({alert, result, timestamp}), do: {alert, result, timestamp}
  defp extract_tuple_3({alert, result, timestamp, _is_first}), do: {alert, result, timestamp}
  
  defp build_diff_content(nil, {_curr_alert, curr_result}) when curr_result != nil do
    # First result ever: show diff with "nothing" (special case per TODO rules)
    changes = [
      %{field: "Status", old: "never run", new: curr_result.status, emoji: "📊"},
      %{field: "Row Count", old: "0", new: to_string(curr_result.total_rows), emoji: "🔢"}
    ]
    
    # Add actual result data if available and not too large
    changes = if curr_result.csv_data && String.length(curr_result.csv_data) < 1000 do
      changes ++ [%{field: "Results Data", old: "No previous data", new: curr_result.csv_data, emoji: "📋"}]
    else
      changes ++ [%{field: "First Results", old: "No previous results", new: "#{curr_result.total_rows} rows found", emoji: "🎯"}]
    end
    
    AlertsWeb.AlertHTML.render_diff_items(changes)
  end
  
  defp build_diff_content(nil, _current), do: nil
  
  defp build_diff_content({prev_alert, prev_result, _}, {curr_alert, curr_result}) do
    cond do
      # Result diff: current result vs previous result (only if different)
      curr_result != nil and prev_result != nil and results_different?(prev_result, curr_result) ->
        AlertsWeb.AlertHTML.render_diff_items(build_result_diff_changes(prev_result, curr_result))
      
      # Alert diff: current alert vs previous alert (only if different)
      curr_result == nil and prev_alert != nil and alerts_different?(prev_alert, curr_alert) ->
        AlertsWeb.AlertHTML.render_diff_items(build_alert_diff_changes(prev_alert, curr_alert))
      
      # No changes worth showing
      true ->
        nil
    end
  end
  
  # Check if alerts are actually different
  defp alerts_different?(prev_alert, curr_alert) do
    prev_alert.name != curr_alert.name ||
    prev_alert.description != curr_alert.description ||
    prev_alert.query != curr_alert.query ||
    prev_alert.threshold != curr_alert.threshold ||
    prev_alert.schedule != curr_alert.schedule
  end
  
  
  
  
  defp build_alert_diff_changes(prev_alert, curr_alert) do
    changes = []
    
    changes = if String.trim(prev_alert.name || "") != String.trim(curr_alert.name || "") do
      changes ++ [%{field: "Name", old: prev_alert.name, new: curr_alert.name, emoji: "📝"}]
    else
      changes
    end
    
    changes = if String.trim(prev_alert.description || "") != String.trim(curr_alert.description || "") do
      changes ++ [%{field: "Description", old: prev_alert.description, new: curr_alert.description, emoji: "📄"}]
    else
      changes
    end
    
    # Normalize line endings and trim for comparison
    prev_query_normalized = (prev_alert.query || "") 
      |> String.replace(~r/\r\n|\r/, "\n") 
      |> String.trim()
    curr_query_normalized = (curr_alert.query || "") 
      |> String.replace(~r/\r\n|\r/, "\n") 
      |> String.trim()
    
    changes = if prev_query_normalized == curr_query_normalized do
      changes  # No SQL change - don't add diff
    else
      changes ++ [%{field: "SQL Query", old: prev_alert.query, new: curr_alert.query, emoji: "🔍"}]
    end
    
    changes = if prev_alert.threshold != curr_alert.threshold do
      changes ++ [%{field: "Threshold", old: prev_alert.threshold, new: curr_alert.threshold, emoji: "📊"}]
    else
      changes
    end
    
    changes = if prev_alert.schedule != curr_alert.schedule do
      changes ++ [%{field: "Schedule", old: prev_alert.schedule, new: curr_alert.schedule, emoji: "⏰"}]
    else
      changes
    end
    
    changes = if prev_alert.data_source_id != curr_alert.data_source_id do
      changes ++ [%{field: "Data Source", old: prev_alert.data_source_id, new: curr_alert.data_source_id, emoji: "🗃️"}]
    else
      changes
    end
    
    changes
  end
  
  defp build_result_diff_changes(prev_result, curr_result) do
    changes = []
    
    changes = if prev_result.status != curr_result.status do
      changes ++ [%{field: "Status", old: prev_result.status, new: curr_result.status, emoji: "📊"}]
    else
      changes
    end
    
    changes = if prev_result.total_rows != curr_result.total_rows do
      changes ++ [%{field: "Row Count", old: to_string(prev_result.total_rows), new: to_string(curr_result.total_rows), emoji: "🔢"}]
    else
      changes
    end
    
    changes = if prev_result.error_message != curr_result.error_message do
      old_error = if prev_result.error_message, do: prev_result.error_message, else: "No error"
      new_error = if curr_result.error_message, do: curr_result.error_message, else: "No error"
      changes ++ [%{field: "Error", old: old_error, new: new_error, emoji: "⚠️"}]
    else
      changes
    end
    
    # Show CSV data diff for small result sets
    changes = if prev_result.result_hash != curr_result.result_hash && 
                 String.length(prev_result.csv_data || "") < 200 &&
                 String.length(curr_result.csv_data || "") < 200 do
      changes ++ [%{field: "Data", old: prev_result.csv_data || "", new: curr_result.csv_data || "", emoji: "📋"}]
    else
      changes
    end
    
    changes
  end
  
  defp results_different?(prev_result, curr_result) do
    prev_result.status != curr_result.status ||
    prev_result.total_rows != curr_result.total_rows ||
    prev_result.result_hash != curr_result.result_hash ||
    prev_result.error_message != curr_result.error_message
  end

  defp get_config_change_summary(alert) do
    "Name: #{alert.name} | Threshold: #{alert.threshold}"
  end

  defp get_result_change_summary(result) do
    if result.status == "broken" do
      "Error: #{result.error_message}"
    else
      "#{result.total_rows} rows found"
    end
  end

end

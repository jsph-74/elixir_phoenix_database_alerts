defmodule Alerts.Integration.AlertLinearDatesTest do
  use Alerts.DataCase, async: true
  alias Alerts.Business.Alerts, as: AlertLib
  alias Alerts.Business.AlertResultsHistory
  import Factory

  @moduletag :integration

  describe "Alert Linear Date Management" do
    test "alert lifecycle follows linear date pattern T0-T4" do
      # T0) Create an alert
      data_source = insert!(:data_source)
      
      _t0 = ~N[2025-01-01 10:00:00]
      # Mock time for T0
      
      {:ok, alert} = AlertLib.create(%{
        "name" => "Test Alert",
        "context" => "test",
        "query" => "SELECT 1",
        "description" => "Test alert description", 
        "threshold" => 10,
        "data_source_id" => data_source.id
      })
      
      # T0 assertions
      assert alert.created_at != nil
      assert alert.last_edited != nil  
      assert alert.last_run == nil
      assert alert.last_status_change == nil
      assert alert.status == "never run"
      assert alert.lifecycle_status == "current"
      
      t0_created = alert.created_at
      t0_edited = alert.last_edited
      
      # Both should be same time at creation
      assert t0_created == t0_edited
      
      # Sleep to ensure different timestamps
      :timer.sleep(1100)
      
      # T1) Run alert manually - gets 2 rows (under threshold)
      results1 = %{rows: [["a"], ["b"]], columns: ["col1"], num_rows: 2, total_rows: 2, is_truncated: false}
      
      # Mock the alert run to return our results
      updated_alert_t1 = AlertLib.run_with_results(alert.id, {:ok, results1})
      
      # T1 assertions
      assert updated_alert_t1.created_at == t0_created  # preserved
      assert updated_alert_t1.last_edited == t0_edited  # unchanged
      assert updated_alert_t1.last_run != nil           # updated
      assert updated_alert_t1.last_status_change != nil # updated (never run -> under_threshold)
      assert updated_alert_t1.status == "under_threshold"
      
      t1_run = updated_alert_t1.last_run
      t1_status_change = updated_alert_t1.last_status_change
      
      # Should have 1 snapshot
      snapshots_t1 = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)
      assert length(snapshots_t1) == 1
      assert hd(snapshots_t1).status == "under_threshold"
      assert hd(snapshots_t1).total_rows == 2
      
      # Sleep for T2
      :timer.sleep(1100)
      
      # T2) Database changes, alert runs again - gets 5 rows (still under threshold)
      results2 = %{rows: [["a"], ["b"], ["c"], ["d"], ["e"]], columns: ["col1"], num_rows: 5, total_rows: 5, is_truncated: false}
      
      updated_alert_t2 = AlertLib.run_with_results(alert.id, {:ok, results2})
      
      # T2 assertions
      assert updated_alert_t2.created_at == t0_created  # preserved
      assert updated_alert_t2.last_edited == t0_edited  # unchanged
      assert updated_alert_t2.last_run != t1_run        # updated
      assert updated_alert_t2.last_status_change != t1_status_change # updated (results changed)
      assert updated_alert_t2.status == "under_threshold"
      
      t2_run = updated_alert_t2.last_run
      t2_status_change = updated_alert_t2.last_status_change
      
      # Should have 2 snapshots now
      snapshots_t2 = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)
      assert length(snapshots_t2) == 2
      
      # Sleep for T3
      :timer.sleep(1100)
      
      # T3) User edits alert - changes threshold to 0
      {:ok, updated_alert_t3} = AlertLib.update(updated_alert_t2, %{"threshold" => 0})
      
      # T3 assertions - NEW current alert
      assert updated_alert_t3.created_at == t0_created     # preserved
      assert updated_alert_t3.last_edited != t0_edited     # updated to T3
      assert updated_alert_t3.last_run == t2_run           # copied from old version  
      assert updated_alert_t3.last_status_change == t2_status_change # copied from old version
      assert updated_alert_t3.status == "needs refreshing"
      assert updated_alert_t3.lifecycle_status == "current"
      assert updated_alert_t3.threshold == 0
      
      t3_edited = updated_alert_t3.last_edited
      
      # Verify old alert was marked as old
      old_alert = AlertLib.get!(updated_alert_t2.id)
      assert old_alert.lifecycle_status == "old"
      # Old alert's business dates should be unchanged
      assert old_alert.created_at == t0_created
      assert old_alert.last_edited == t0_edited  # NOT changed
      assert old_alert.last_run == t2_run
      assert old_alert.last_status_change == t2_status_change
      
      # Should still have 2 snapshots (NO "needs refreshing" snapshot created)
      # "needs refreshing" is a dummy status that doesn't represent real monitoring data
      snapshots_t3 = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)
      assert length(snapshots_t3) == 2
      needs_refreshing_snapshot = Enum.find(snapshots_t3, &(&1.status == "needs refreshing"))
      assert needs_refreshing_snapshot == nil
      
      # Sleep for T4
      :timer.sleep(1100)
      
      # T4) Cron runs - gets 5 results again, now "bad" because threshold is 0
      results4 = %{rows: [["a"], ["b"], ["c"], ["d"], ["e"]], columns: ["col1"], num_rows: 5, total_rows: 5, is_truncated: false}
      
      updated_alert_t4 = AlertLib.run_with_results(updated_alert_t3.id, {:ok, results4})
      
      # T4 assertions
      assert updated_alert_t4.created_at == t0_created     # preserved
      assert updated_alert_t4.last_edited == t3_edited     # unchanged
      assert updated_alert_t4.last_run != t2_run           # updated
      assert updated_alert_t4.last_status_change != t2_status_change # updated (status changed)
      assert updated_alert_t4.status == "bad"
      assert updated_alert_t4.lifecycle_status == "current"
      
      # Should have 3 snapshots total (T1, T2, T4 - no T3 "needs refreshing")
      snapshots_t4 = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)
      assert length(snapshots_t4) == 3
      
      # Verify timeline shows correct events (excluding "needs refreshing")
      alert_history = AlertLib.get_alert_history(alert.alert_public_id)
      timeline = AlertsWeb.AlertController.create_unified_timeline(alert_history, snapshots_t4)
      
      # Should have 5 events total: 3 snapshots + 2 config changes (created + updated)  
      # No "needs refreshing" snapshots exist, so no filtering needed
      assert length(timeline) == 5  # T4:bad, T3:updated, T2:under_threshold, T1:under_threshold, T0:created
      
      # Verify dates are used correctly in timeline
      config_events = Enum.filter(timeline, &(&1.type == :config_change))
      
      creation_event = Enum.find(config_events, &(&1.title == "Alert created"))
      update_event = Enum.find(config_events, &(&1.title == "Alert updated"))
      
      assert creation_event.timestamp == t0_created
      assert update_event.timestamp == t3_edited
    end
  end
end
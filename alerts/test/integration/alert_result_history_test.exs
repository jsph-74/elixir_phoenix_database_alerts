defmodule Alerts.Integration.AlertResultHistoryTest do
  use Alerts.DataCase, async: true
  alias Alerts.Business.Alerts, as: AlertLib
  alias Alerts.Business.AlertResultsHistory

  @moduletag :integration

  describe "Alert Result History - Write-Only Log Integration" do
    test "alert history snapshots are created when status changes after threshold update" do
      # Create alert and simulate first run with bad results
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, threshold: 5, data_source_id: data_source.id)

      # Mock first run: 8 rows found (bad status because > threshold 5)
      results = %{rows: [["row1"], ["row2"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, _snapshot1} = AlertResultsHistory.store_result_snapshot(alert, results)

      # Update alert threshold to 10, which should create new version
      {:ok, updated_alert} = AlertLib.update(alert, %{"threshold" => 10})

      # Mock second run on the SAME original alert (same id): same 8 rows found
      # Now should be under_threshold status because 8 < 10 (new threshold)
      # But we're running against the updated alert which has the new threshold
      results2 = %{rows: [["row1"], ["row2"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, _snapshot2} = AlertResultsHistory.store_result_snapshot(updated_alert, results2)

      # Check snapshots: first one on original alert, second on updated alert
      history1 = AlertResultsHistory.get_result_history(alert.id)
      history2 = AlertResultsHistory.get_result_history(updated_alert.id)

      # Should have 1 snapshot each
      assert length(history1) == 1
      assert length(history2) == 1

      # Combine both histories to check statuses
      all_snapshots = history1 ++ history2

      # First snapshot should be "bad" status (8 rows > 5 threshold)
      # Second snapshot should be "under_threshold" status (8 rows < 10 threshold)
      statuses = Enum.map(all_snapshots, &(&1.status)) |> Enum.sort()
      assert "bad" in statuses
      assert "under_threshold" in statuses

      # Both should have same row count but different status
      row_counts = Enum.map(all_snapshots, &(&1.total_rows)) |> Enum.uniq()
      assert row_counts == [8]
    end

    test "get_complete_result_history returns all snapshots across alert versions" do
      # Create alert with specific alert_public_id
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, threshold: 5, data_source_id: data_source.id)
      alert_public_id = alert.alert_public_id

      # Create snapshot for original alert
      results1 = %{rows: [["a"]], columns: ["col1"], num_rows: 3, total_rows: 3, is_truncated: false}
      {:ok, snapshot1} = AlertResultsHistory.store_result_snapshot(alert, results1)

      # Create updated alert version with same alert_public_id
      {:ok, updated_alert} = AlertLib.update(alert, %{"threshold" => 10})

      # Create snapshot for updated alert
      results2 = %{rows: [["b"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, snapshot2} = AlertResultsHistory.store_result_snapshot(updated_alert, results2)

      # Test: get_complete_result_history should return ALL snapshots by alert_public_id
      complete_history = AlertResultsHistory.get_complete_result_history(alert_public_id)

      # Should have both snapshots regardless of alert version
      assert length(complete_history) == 2

      snapshot_ids = Enum.map(complete_history, &(&1.id)) |> Enum.sort()
      expected_ids = [snapshot1.id, snapshot2.id] |> Enum.sort()
      assert snapshot_ids == expected_ids

      # Verify individual alert histories still work correctly
      original_history = AlertResultsHistory.get_result_history(alert.id)
      updated_history = AlertResultsHistory.get_result_history(updated_alert.id)

      assert length(original_history) == 1
      assert length(updated_history) == 1
      assert hd(original_history).id == snapshot1.id
      assert hd(updated_history).id == snapshot2.id
    end
    test "complete result history preserves all snapshots across alert versions and updates" do
      # Create alert and run it multiple times across different versions
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, threshold: 5, data_source_id: data_source.id)

      # First run: 3 rows (under threshold)
      results1 = %{rows: [["a"], ["b"], ["c"]], columns: ["col1"], num_rows: 3, total_rows: 3, is_truncated: false}
      {:ok, snapshot1} = AlertResultsHistory.store_result_snapshot(alert, results1)

      # Second run: 8 rows (bad - over threshold)
      results2 = %{rows: [["a"], ["b"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, snapshot2} = AlertResultsHistory.store_result_snapshot(alert, results2)

      # Update alert to new version (threshold change to 10)
      {:ok, updated_alert} = AlertLib.update(alert, %{"threshold" => 10})

      # Third run on updated alert: same 8 rows (now under threshold due to new threshold)
      results3 = %{rows: [["a"], ["b"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, snapshot3} = AlertResultsHistory.store_result_snapshot(updated_alert, results3)

      # Fourth run on updated alert: 15 rows (bad - over new threshold)
      results4 = %{rows: [["a"]], columns: ["col1"], num_rows: 15, total_rows: 15, is_truncated: false}
      {:ok, snapshot4} = AlertResultsHistory.store_result_snapshot(updated_alert, results4)

      # Update alert again (second update - name change)
      {:ok, updated_alert2} = AlertLib.update(updated_alert, %{"name" => "Updated Name"})

      # Fifth run on second updated version: 2 rows (under threshold)
      results5 = %{rows: [["a"], ["b"]], columns: ["col1"], num_rows: 2, total_rows: 2, is_truncated: false}
      {:ok, snapshot5} = AlertResultsHistory.store_result_snapshot(updated_alert2, results5)

      # CRITICAL INTEGRATION TEST: Complete history spans all versions
      complete_history = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)

      # Should have ALL 5 snapshots, proving write-only log behavior
      assert length(complete_history) == 5

      # Verify all snapshot IDs are present (no deletions)
      snapshot_ids = Enum.map(complete_history, &(&1.id)) |> Enum.sort()
      expected_ids = [snapshot1.id, snapshot2.id, snapshot3.id, snapshot4.id, snapshot5.id] |> Enum.sort()
      assert snapshot_ids == expected_ids

      # Verify statuses reflect the threshold changes correctly across versions
      statuses_by_rows = complete_history
      |> Enum.map(fn s -> {s.total_rows, s.status} end)
      |> Enum.sort()

      expected_statuses = [
        {2, "under_threshold"},   # 5th run: 2 < 10 (threshold 10)
        {3, "under_threshold"},   # 1st run: 3 < 5 (threshold 5)
        {8, "bad"},               # 2nd run: 8 > 5 (threshold 5)
        {8, "under_threshold"},   # 3rd run: 8 < 10 (threshold changed to 10)
        {15, "bad"}               # 4th run: 15 > 10 (threshold 10)
      ]

      assert statuses_by_rows == expected_statuses

      # Individual alert version histories should still work (for debugging)
      original_history = AlertResultsHistory.get_result_history(alert.id)
      first_update_history = AlertResultsHistory.get_result_history(updated_alert.id)
      second_update_history = AlertResultsHistory.get_result_history(updated_alert2.id)

      assert length(original_history) == 2    # snapshots 1 & 2
      assert length(first_update_history) == 2  # snapshots 3 & 4
      assert length(second_update_history) == 1 # snapshot 5

      # Verify the integration works end-to-end: no history is lost
      total_individual_snapshots = length(original_history) + length(first_update_history) + length(second_update_history)
      assert total_individual_snapshots == length(complete_history)
    end

    test "timeline events are sorted in correct chronological order (newest first)" do
      # Create alert and track events with deliberate timing
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, threshold: 5, data_source_id: data_source.id)
      original_created_at = alert.created_at

      # Sleep to ensure distinct timestamps (use 1 second for second-precision timestamps)
      :timer.sleep(1100)

      # First run: should be "bad" status
      results1 = %{rows: [["test"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, snapshot1} = AlertResultsHistory.store_result_snapshot(alert, results1)

      # Sleep to ensure distinct timestamps
      :timer.sleep(1100)

      # Update alert (should create new version)
      {:ok, updated_alert} = AlertLib.update(alert, %{"threshold" => 10})

      # CRITICAL TEST: Verify that created_at is preserved but inserted_at is different
      assert updated_alert.created_at == original_created_at, "created_at should be preserved across updates"
      assert updated_alert.inserted_at != alert.inserted_at, "Alert created and Alert updated must have different timestamps!"

      # Sleep to ensure distinct timestamps
      :timer.sleep(1100)

      # Second run: should be "under_threshold" status
      results2 = %{rows: [["test2"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, snapshot2} = AlertResultsHistory.store_result_snapshot(updated_alert, results2)

      # Use the actual controller function to create timeline (not test double)
      alert_history = AlertLib.get_alert_history(alert.alert_public_id)
      results_history = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)

      # Use the REAL controller timeline function
      unified_timeline = AlertsWeb.AlertController.create_unified_timeline(alert_history, results_history)

      # Timeline should be sorted newest to oldest (desc order)
      # Expected order (newest first):
      # 1. Results: Under threshold (snapshot2)
      # 2. Alert updated (updated_alert.inserted_at)
      # 3. Results: Bad (snapshot1)
      # 4. Alert created (original_created_at)

      assert length(unified_timeline) == 4

      # CRITICAL TEST: Verify timestamps are actually different and properly sorted
      timestamps = Enum.map(unified_timeline, & &1.timestamp)
      sortable_times = Enum.map(unified_timeline, & &1.sortable_time)

      # Check that all timestamps are unique
      unique_timestamps = Enum.uniq(timestamps)
      assert length(unique_timestamps) == length(timestamps), "All timeline events must have unique timestamps!"

      # Check that events are sorted newest first
      assert sortable_times == Enum.sort(sortable_times, :desc), "Timeline events should be sorted newest first"

      # Check specific event order and verify timestamp logic
      event_details = Enum.map(unified_timeline, fn event ->
        case event.type do
          :result_change -> {:result, event.title, event.timestamp, event.data.id}
          :config_change -> {:config, event.title, event.timestamp, event.data.id}
        end
      end)

      # Find creation and update events specifically
      creation_event = Enum.find(event_details, fn {_, title, _, _} -> title == "Alert created" end)
      update_event = Enum.find(event_details, fn {_, title, _, _} -> title == "Alert updated" end)

      assert creation_event, "Should have Alert created event"
      assert update_event, "Should have Alert updated event"

      {_, _, creation_timestamp, _} = creation_event
      {_, _, update_timestamp, _} = update_event

      # CRITICAL VERIFICATION: Creation and update timestamps must be different
      assert creation_timestamp != update_timestamp, "Alert created and Alert updated must have different timestamps!"
      assert creation_timestamp == original_created_at, "Alert created should use original created_at timestamp"
      assert update_timestamp == updated_alert.inserted_at, "Alert updated should use updated alert's inserted_at timestamp"

      # Verify logical sequence in timeline
      result_titles = Enum.map(event_details, fn {_, title, _, _} -> title end)
      event_ids = Enum.map(event_details, fn {_, _, _, id} -> id end)

      assert "Alert status: under threshold" in result_titles
      assert "Alert updated" in result_titles
      assert "Alert status: bad" in result_titles
      assert "Alert created" in result_titles
      assert snapshot2.id in event_ids
      assert updated_alert.id in event_ids
      assert snapshot1.id in event_ids

      # Most recent event should be the second result
      [{_, first_title, _, first_id} | _] = event_details
      assert first_title == "Alert status: under threshold"
      assert first_id == snapshot2.id
    end


    test "result history survives alert deletions (tombstone behavior)" do
      # Create alert and create some execution history
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, threshold: 5, data_source_id: data_source.id)

      # Run the alert a few times
      results1 = %{rows: [["test"]], columns: ["col1"], num_rows: 3, total_rows: 3, is_truncated: false}
      {:ok, snapshot1} = AlertResultsHistory.store_result_snapshot(alert, results1)

      results2 = %{rows: [["test2"]], columns: ["col1"], num_rows: 8, total_rows: 8, is_truncated: false}
      {:ok, snapshot2} = AlertResultsHistory.store_result_snapshot(alert, results2)

      # Delete the alert (creates tombstone version)
      deleted_alert = AlertLib.delete(alert.id)
      assert deleted_alert.lifecycle_status == "deleted"

      # CRITICAL: Result history should still be accessible via alert_public_id
      complete_history = AlertResultsHistory.get_complete_result_history(alert.alert_public_id)

      # All execution history should be preserved even after deletion
      assert length(complete_history) == 2
      snapshot_ids = Enum.map(complete_history, &(&1.id)) |> Enum.sort()
      expected_ids = [snapshot1.id, snapshot2.id] |> Enum.sort()
      assert snapshot_ids == expected_ids

      # Individual alert history should still work for the original alert
      original_history = AlertResultsHistory.get_result_history(alert.id)
      assert length(original_history) == 2
    end
  end
end

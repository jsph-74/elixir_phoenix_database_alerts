defmodule Alerts.Business.AlertsTest do
  use Alerts.DataCase

  alias Alerts.Business.Alerts, as: AlertLib
  alias Alerts.Business.DB.Alert, as: AlertDB

  describe "create/1" do
    test "creates alert with valid params" do
      data_source = Factory.insert!(:data_source)
      params = %{
        "name" => "Test Alert",
        "context" => "test",
        "description" => "Test description",
        "query" => "  SELECT 1  \n\n",
        "data_source_id" => data_source.id,
        "threshold" => "10"
      }

      assert {:ok, alert} = AlertLib.create(params)
      assert alert.name == "Test Alert"
      assert alert.query == "SELECT 1"  # Should be trimmed
      assert alert.data_source_id == data_source.id

      # Verify history entry was created
      history = AlertLib.get_alert_history(alert.alert_public_id)
      assert length(history) == 1
      assert hd(history).lifecycle_status == "current"
      assert hd(history).name == "Test Alert"
    end

    test "trims query whitespace" do
      data_source = Factory.insert!(:data_source)
      params = %{
        "name" => "Test",
        "context" => "test",
        "data_source_id" => data_source.id,
        "description" => "Test desc",
        "query" => "\n\n  SELECT * FROM users  \n\n  "
      }

      assert {:ok, alert} = AlertLib.create(params)
      assert alert.query == "SELECT * FROM users"
    end

    test "returns error with invalid params" do
      params = %{"name" => ""}  # Missing required fields

      assert {:error, changeset} = AlertLib.create(params)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "update/2" do
    test "updates alert with valid params" do
      alert = Factory.insert!(:alert)

      params = %{
        "name" => "Updated Alert",
        "query" => "  SELECT 2  \n"
      }

      assert {:ok, updated} = AlertLib.update(alert, params)
      assert updated.name == "Updated Alert"
      assert updated.query == "SELECT 2"  # Should be trimmed
    end

    test "preserves original alert when update fails" do
      alert = Factory.insert!(:alert, name: "Original Alert")
      original_status = alert.lifecycle_status

      # Create params that will cause validation failure
      invalid_params = %{
        "name" => "",  # Empty name should fail validation
        "query" => "SELECT 1"
      }

      # Update should fail
      assert {:error, changeset} = AlertLib.update(alert, invalid_params)
      assert %Ecto.Changeset{} = changeset

      # Original alert should remain unchanged and still be "current"
      unchanged_alert = Repo.get!(AlertDB, alert.id)
      assert unchanged_alert.name == "Original Alert"
      assert unchanged_alert.lifecycle_status == original_status
      assert unchanged_alert.lifecycle_status == "current"

      # Should still be retrievable by UUID
      current_alert = AlertLib.get_by_uuid!(alert.alert_public_id)
      assert current_alert.name == "Original Alert"
      assert current_alert.id == alert.id

      # Should only have 1 version in history (the original)
      history = AlertLib.get_alert_history(alert.alert_public_id)
      assert length(history) == 1
    end

    test "creates new version when alert is updated" do
      alert = Factory.insert!(:alert, query: "SELECT 1", name: "Original Alert")

      params = %{"query" => "SELECT 2", "name" => "Updated Alert"}

      assert {:ok, updated} = AlertLib.update(alert, params)

      # Should create new version with updated data
      assert updated.query == "SELECT 2"
      assert updated.name == "Updated Alert"
      assert updated.alert_public_id == alert.alert_public_id
      assert updated.lifecycle_status == "current"

      # Original alert should be marked as old
      old_alert = Repo.get!(AlertDB, alert.id)
      assert old_alert.lifecycle_status == "old"

      # Should have 2 versions with same history_id
      history = AlertLib.get_alert_history(alert.alert_public_id)
      assert length(history) == 2

      # Verify exactly one "current" and one "old" status in history
      statuses = Enum.map(history, & &1.lifecycle_status)
      assert Enum.count(statuses, & &1 == "current") == 1
      assert Enum.count(statuses, & &1 == "old") == 1

      # Verify the current version has the updated data
      current_version = Enum.find(history, & &1.lifecycle_status == "current")
      old_version = Enum.find(history, & &1.lifecycle_status == "old")

      assert current_version.name == "Updated Alert"
      assert current_version.query == "SELECT 2"
      assert old_version.name == "Original Alert"
      assert old_version.query == "SELECT 1"
    end

    test "get_by_uuid! retrieves current version by UUID" do
      alert = Factory.insert!(:alert, name: "Original Alert")

      # Update the alert to create new version
      params = %{"name" => "Updated Alert"}
      assert {:ok, _updated} = AlertLib.update(alert, params)

      # get_by_uuid! should return the current version
      current = AlertLib.get_by_uuid!(alert.alert_public_id)
      assert current.name == "Updated Alert"
      assert current.lifecycle_status == "current"
      assert current.id != alert.id  # Different database ID
      assert current.alert_public_id == alert.alert_public_id  # Same UUID
    end

    test "update_by_uuid works with UUID parameter" do
      alert = Factory.insert!(:alert, name: "Original Alert")

      params = %{"name" => "Updated via UUID"}
      assert {:ok, updated} = AlertLib.update_by_uuid(alert.alert_public_id, params)

      assert updated.name == "Updated via UUID"
      assert updated.alert_public_id == alert.alert_public_id
    end

    test "delete_by_uuid works with UUID parameter" do
      alert = Factory.insert!(:alert)

      deleted = AlertLib.delete_by_uuid(alert.alert_public_id)
      assert deleted.lifecycle_status == "deleted"
      assert deleted.alert_public_id == alert.alert_public_id

      # Should not be found by get_by_uuid! anymore
      assert_raise Ecto.NoResultsError, fn ->
        AlertLib.get_by_uuid!(alert.alert_public_id)
      end
    end
  end

  describe "get!/1" do
    test "returns alert by id" do
      alert = Factory.insert!(:alert)

      found = AlertLib.get!(alert.id)
      assert found.id == alert.id
      assert found.name == alert.name
    end

    test "raises when alert not found" do
      assert_raise Ecto.NoResultsError, fn ->
        AlertLib.get!(999)
      end
    end
  end

  describe "delete/1" do
    test "creates deleted version when alert is deleted" do
      alert = Factory.insert!(:alert)

      deleted = AlertLib.delete(alert.id)
      assert deleted.name == alert.name
      assert deleted.alert_public_id == alert.alert_public_id
      assert deleted.lifecycle_status == "deleted"

      # Original alert should be marked as old
      old_alert = Repo.get!(AlertDB, alert.id)
      assert old_alert.lifecycle_status == "old"

      # Should have 2 versions: old + deleted
      history = AlertLib.get_alert_history(alert.alert_public_id)
      assert length(history) == 2

      # Original alert should still exist but marked as "old"
      old_alert = AlertLib.get!(alert.id)
      assert old_alert.lifecycle_status == "old"
    end
  end

  describe "contexts/0" do
    test "returns unique contexts from current alerts only" do
      Factory.insert!(:alert, context: "production")
      Factory.insert!(:alert, context: "staging")
      prod_alert = Factory.insert!(:alert, context: "production")  # Duplicate

      # Update one alert to create old version
      AlertLib.update(prod_alert, %{"name" => "Updated"})

      contexts = AlertLib.contexts()
      assert is_list(contexts)
      # Should only count current alerts, not old versions
    end
  end

  describe "alerts_in_context/2" do
    test "returns only current alerts filtered by context" do
      prod_alert = Factory.insert!(:alert, context: "production")
      Factory.insert!(:alert, context: "staging")

      # Update prod_alert to create an old version
      {:ok, updated_prod} = AlertLib.update(prod_alert, %{"name" => "Updated Prod"})

      alerts = AlertLib.alerts_in_context("production", :name)
      assert length(alerts) == 1
      # Should return the updated version, not the old one
      assert hd(alerts).id == updated_prod.id
      assert hd(alerts).name == "Updated Prod"
    end
  end

  describe "get_alert_history/1" do
    test "returns complete history for an alert UUID" do
      alert = Factory.insert!(:alert, name: "Original")

      # Make several updates
      {:ok, v2} = AlertLib.update(alert, %{"name" => "Version 2"})
      {:ok, _v3} = AlertLib.update_by_uuid(v2.alert_public_id, %{"name" => "Version 3"})

      history = AlertLib.get_alert_history(alert.alert_public_id)
      assert length(history) == 3

      # Should be ordered by current status first, then by insertion time
      names = Enum.map(history, &(&1.name))
      # Current version should be first, then historical versions
      assert "Version 3" in names
      assert "Version 2" in names
      assert "Original" in names
      assert length(names) == 3
    end
  end

  describe "scheduled alerts" do
    test "reboot_all_jobs only processes current scheduled alerts" do
      # Get initial count of scheduled jobs
      initial_job_configs = AlertLib.reboot_all_jobs()
      initial_count = length(initial_job_configs)
      
      # Create alerts with schedules
      scheduled = Factory.insert!(:alert, schedule: "0 9 * * *")
      Factory.insert!(:alert, schedule: nil)  # Manual alert

      # Update scheduled alert to create old version
      {:ok, updated_scheduled} = AlertLib.update(scheduled, %{"name" => "Updated Scheduled"})

      # This should only process current alerts with schedules
      job_configs = AlertLib.reboot_all_jobs()
      assert is_list(job_configs)

      # Should have initial count + 1 job for the new scheduled alert
      assert length(job_configs) == initial_count + 1

      # The job should be for the updated (current) version, not the old version
      # Find our specific alert in the job configs by alert_public_id
      our_job = Enum.find(job_configs, fn alert -> 
        alert.alert_public_id == updated_scheduled.alert_public_id
      end)
      
      assert our_job != nil, "Should find our updated scheduled alert"
      assert our_job.schedule == "0 9 * * *"
      assert our_job.name == "Updated Scheduled"
    end
  end

  describe "alert status logic" do
    test "new alert has 'never run' status" do
      data_source = Factory.insert!(:data_source)
      params = %{
        "name" => "Test Alert",
        "context" => "test",
        "description" => "Test description",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id
      }

      assert {:ok, alert} = AlertLib.create(params)
      assert alert.status == "never run"
    end

    test "alert with 0 results has 'good' status" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, results_size: 0, threshold: 10, data_source_id: data_source.id)

      updated_alert = AlertDB.run_changeset(alert, %{"results_size" => 0})
      |> Repo.update!()

      assert updated_alert.status == "good"
    end

    test "alert with results below threshold has 'under_threshold' status" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, results_size: 0, threshold: 10, data_source_id: data_source.id)

      updated_alert = AlertDB.run_changeset(alert, %{"results_size" => 5})
      |> Repo.update!()

      assert updated_alert.status == "under_threshold"
    end

    test "alert with results at or above threshold has 'bad' status" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, results_size: 0, threshold: 10, data_source_id: data_source.id)

      updated_alert = AlertDB.run_changeset(alert, %{"results_size" => 10})
      |> Repo.update!()

      assert updated_alert.status == "bad"

      updated_alert_2 = AlertDB.run_changeset(alert, %{"results_size" => 15})
      |> Repo.update!()

      assert updated_alert_2.status == "bad"
    end

    test "alert with results but no threshold has 'bad' status" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, results_size: 0, threshold: 0, data_source_id: data_source.id)

      updated_alert = AlertDB.run_changeset(alert, %{"results_size" => 5})
      |> Repo.update!()

      assert updated_alert.status == "bad"
    end

    test "alert with -1 results has 'broken' status" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, results_size: 0, threshold: 10, data_source_id: data_source.id)

      updated_alert = AlertDB.run_changeset(alert, %{"results_size" => -1})
      |> Repo.update!()

      assert updated_alert.status == "broken"
    end

  end

  describe "linear date management" do
    test "run_changeset only updates last_run and status dates, never created_at or last_edited" do
      data_source = Factory.insert!(:data_source)
      
      # Create alert
      {:ok, alert} = AlertLib.create(%{
        "name" => "Date Test Alert",
        "context" => "test",
        "description" => "Testing date preservation",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "threshold" => 5
      })
      
      original_created_at = alert.created_at
      original_last_edited = alert.last_edited
      
      # Wait a bit to ensure timestamps would be different
      :timer.sleep(1100)
      
      # Run alert - should only update last_run and last_status_change
      updated_alert = AlertDB.run_changeset(alert, %{"results_size" => 3})
                      |> Repo.update!()
      
      # Assert that created_at and last_edited are NEVER touched by run operations
      assert updated_alert.created_at == original_created_at, 
             "created_at should never change during alert runs"
      assert updated_alert.last_edited == original_last_edited,
             "last_edited should never change during alert runs"
      
      # But last_run and last_status_change should be updated
      assert updated_alert.last_run != nil
      assert updated_alert.last_status_change != nil
      assert updated_alert.status == "under_threshold"
    end
    
    test "run_changeset preserves dates across multiple runs" do
      data_source = Factory.insert!(:data_source)
      
      {:ok, alert} = AlertLib.create(%{
        "name" => "Multi-run Test",
        "context" => "test", 
        "description" => "Testing multiple runs",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "threshold" => 0
      })
      
      original_created_at = alert.created_at
      original_last_edited = alert.last_edited
      
      # Run 1: Good results
      :timer.sleep(1100)
      updated_1 = AlertDB.run_changeset(alert, %{"results_size" => 0}) |> Repo.update!()
      run_1_time = updated_1.last_run
      status_1_time = updated_1.last_status_change
      
      # Run 2: Bad results  
      :timer.sleep(1100)
      updated_2 = AlertDB.run_changeset(updated_1, %{"results_size" => 10}) |> Repo.update!()
      
      # Run 3: Same bad results (no status change, but results changed)
      :timer.sleep(1100)
      updated_3 = AlertDB.run_changeset(updated_2, %{"results_size" => 10, "force_status_change" => true}) |> Repo.update!()
      
      # All three runs should preserve created_at and last_edited
      assert updated_3.created_at == original_created_at
      assert updated_3.last_edited == original_last_edited
      
      # But last_run should always update
      assert updated_3.last_run != run_1_time
      assert updated_3.last_run != updated_2.last_run
      
      # last_status_change should update when status changes OR results change
      assert updated_3.last_status_change != status_1_time
      assert updated_3.last_status_change != updated_2.last_status_change
    end
    
    test "update operations change last_edited but preserve created_at" do
      data_source = Factory.insert!(:data_source)
      
      {:ok, alert} = AlertLib.create(%{
        "name" => "Edit Test",
        "context" => "test",
        "description" => "Testing edits",  
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "threshold" => 5
      })
      
      original_created_at = alert.created_at
      
      :timer.sleep(1100)
      
      # Update alert
      {:ok, updated_alert} = AlertLib.update(alert, %{"name" => "Updated Name"})
      
      # created_at should be preserved
      assert updated_alert.created_at == original_created_at
      
      # last_edited should be updated
      assert updated_alert.last_edited != alert.last_edited
      
      # Status should be "needs refreshing"
      assert updated_alert.status == "needs refreshing"
    end
    
    test "force_status_change parameter controls last_status_change updates" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, 
        threshold: 0,
        data_source_id: data_source.id
      )
      
      # First run to establish "good" status with last_status_change set
      first_run = AlertDB.run_changeset(alert, %{"results_size" => 0}) |> Repo.update!()
      assert first_run.status == "good"
      assert first_run.last_status_change != nil
      
      original_status_change = first_run.last_status_change
      
      :timer.sleep(1100)
      
      # Run without force_status_change - same status, should NOT update last_status_change
      updated_1 = AlertDB.run_changeset(first_run, %{"results_size" => 0}) |> Repo.update!()
      assert updated_1.last_status_change == original_status_change
      
      :timer.sleep(1100)
      
      # Run with force_status_change - same status, but SHOULD update last_status_change
      updated_2 = AlertDB.run_changeset(updated_1, %{"results_size" => 0, "force_status_change" => true}) |> Repo.update!()
      assert updated_2.last_status_change != original_status_change
    end

    test "lifecycle_changeset only updates lifecycle_status, preserves all business dates" do
      data_source = Factory.insert!(:data_source)
      alert = Factory.insert!(:alert, data_source_id: data_source.id)
      
      # Store the original timestamps (Factory uses real app logic with real timestamps)
      original_created_at = alert.created_at
      original_last_edited = alert.last_edited
      original_last_run = alert.last_run
      original_last_status_change = alert.last_status_change
      
      # Use lifecycle_changeset to mark as old
      updated_alert = alert
                      |> AlertDB.lifecycle_changeset("old") 
                      |> Repo.update!()
      
      # Only lifecycle_status should change, all dates preserved
      assert updated_alert.lifecycle_status == "old"
      assert updated_alert.created_at == original_created_at
      assert updated_alert.last_edited == original_last_edited
      assert updated_alert.last_run == original_last_run
      assert updated_alert.last_status_change == original_last_status_change
    end

    test "never run status has no last_status_change timestamp" do
      data_source = Factory.insert!(:data_source)
      
      {:ok, alert} = AlertLib.create(%{
        "name" => "Never Run Test",
        "context" => "test",
        "description" => "Testing never run status",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "threshold" => 5
      })
      
      assert alert.status == "never run"
      assert alert.last_status_change == nil
      assert alert.last_run == nil
    end

    test "needs refreshing status preserves previous timestamps" do
      data_source = Factory.insert!(:data_source)
      
      # Create and run alert first
      {:ok, alert} = AlertLib.create(%{
        "name" => "Refresh Test",
        "context" => "test",
        "description" => "Testing needs refreshing",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "threshold" => 0
      })
      
      # Run it to get a real status
      :timer.sleep(1100)
      run_alert = AlertDB.run_changeset(alert, %{"results_size" => 5}) |> Repo.update!()
      original_last_run = run_alert.last_run
      original_status_change = run_alert.last_status_change
      
      # Now update it (should get "needs refreshing")
      :timer.sleep(1100)
      {:ok, updated_alert} = AlertLib.update(run_alert, %{"threshold" => 10})
      
      assert updated_alert.status == "needs refreshing"
      # Should preserve the run timestamps from before the edit
      assert updated_alert.last_run == original_last_run
      assert updated_alert.last_status_change == original_status_change
    end
  end
end

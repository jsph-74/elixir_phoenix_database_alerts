defmodule Alerts.Business.JobsTest do
  use Alerts.DataCase

  alias Alerts.Business.Jobs
  alias Alerts.Factory

  describe "alert job naming" do
    test "generates job name from alert UUID" do
      alert = Factory.build(:alert, alert_public_id: "123e4567-e89b-12d3-a456-426614174000")

      job_name = Jobs.get_alert_job_name(alert)
      assert job_name == :"alert_123e4567-e89b-12d3-a456-426614174000"
    end

    test "generates job name from string UUID" do
      uuid = "123e4567-e89b-12d3-a456-426614174000"

      job_name = Jobs.get_alert_job_name(uuid)
      assert job_name == :"alert_123e4567-e89b-12d3-a456-426614174000"
    end

    test "generates job name from integer ID" do
      job_name = Jobs.get_alert_job_name(123)
      assert job_name == :alert_123
    end
  end

  describe "alert job lifecycle" do
    test "save_alert_job skips alerts without schedule" do
      alert_no_schedule = Factory.build(:alert, schedule: nil)
      alert_empty_schedule = Factory.build(:alert, schedule: "")

      # Should return alert unchanged
      assert Jobs.save_alert_job(alert_no_schedule) == alert_no_schedule
      assert Jobs.save_alert_job(alert_empty_schedule) == alert_empty_schedule
    end
  end
end

defmodule Alerts.Integration.DataSourceAlertIntegrationTest do
  use Alerts.DataCase, async: true
  alias Alerts.Business.DataSources
  alias Alerts.Business.DB.DataSource

  @moduletag :integration

  describe "DataSource and Alert Integration" do
    test "prevents deletion when alerts are using the data source" do
      data_source = Factory.insert!(:data_source, name: "in_use_db")
      Factory.insert!(:alert, data_source_id: data_source.id)

      assert {:error, message} = DataSources.delete_data_source(data_source)
      assert message =~ "Cannot delete data source"
      assert message =~ "in_use_db"
      assert message =~ "1 alert(s) are still using it"

      # Should still exist
      assert Alerts.Repo.get(DataSource, data_source.id)
    end

    test "counts alerts using data source by ID" do
      data_source = Factory.insert!(:data_source, name: "test_db")
      Factory.insert!(:alert, data_source_id: data_source.id)
      Factory.insert!(:alert, data_source_id: data_source.id)

      # Create alert with different data source
      other_ds = Factory.insert!(:data_source, name: "other_db")
      Factory.insert!(:alert, data_source_id: other_ds.id)

      assert DataSources.count_alerts_using_data_source_id(data_source.id) == 2
      assert DataSources.count_alerts_using_data_source_id(other_ds.id) == 1
      assert DataSources.count_alerts_using_data_source_id(999) == 0
    end

    test "only counts current alerts" do
      data_source = Factory.insert!(:data_source, name: "test_db")
      _alert = Factory.insert!(:alert, data_source_id: data_source.id)
      Factory.insert!(:alert, data_source_id: data_source.id, lifecycle_status: "old")
      Factory.insert!(:alert, data_source_id: data_source.id, lifecycle_status: "deleted")

      # Should only count current alert
      assert DataSources.count_alerts_using_data_source_id(data_source.id) == 1
    end

    test "returns usage statistics for all data sources" do
      ds1 = Factory.insert!(:data_source, name: "db1")
      ds2 = Factory.insert!(:data_source, name: "db2")

      Factory.insert!(:alert, data_source_id: ds1.id)
      Factory.insert!(:alert, data_source_id: ds1.id)
      Factory.insert!(:alert, data_source_id: ds2.id)

      stats = DataSources.get_data_source_usage_stats()
      assert stats["db1"] == 2
      assert stats["db2"] == 1
    end

    test "only counts current alerts in statistics" do
      data_source = Factory.insert!(:data_source, name: "test_db")
      Factory.insert!(:alert, data_source_id: data_source.id, lifecycle_status: "current")
      Factory.insert!(:alert, data_source_id: data_source.id, lifecycle_status: "old")
      Factory.insert!(:alert, data_source_id: data_source.id, lifecycle_status: "deleted")

      stats = DataSources.get_data_source_usage_stats()
      assert stats["test_db"] == 1
    end
  end
end

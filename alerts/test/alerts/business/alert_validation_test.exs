defmodule Alerts.Business.AlertValidationTest do
  use Alerts.DataCase
  
  alias Alerts.Business.DB.Alert
  alias Alerts.Factory

  describe "query validation skips connectivity errors" do
    test "validation passes in test environment" do
      data_source = Factory.insert!(:data_source)
      
      params = %{
        "name" => "Test Alert",
        "context" => "test", 
        "description" => "Test description",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id
      }
      
      changeset = Alert.new_changeset(params)
      
      # Should pass validation in test environment (no ODBC calls)
      assert changeset.valid?
      refute Keyword.has_key?(changeset.errors, :query)
    end
    
    test "handles string data source IDs correctly" do
      data_source = Factory.insert!(:data_source)
      
      params = %{
        "name" => "Test Alert",
        "context" => "test",
        "description" => "Test description",
        "query" => "SELECT 1",
        "data_source_id" => to_string(data_source.id)  # String ID
      }
      
      changeset = Alert.new_changeset(params)
      # Should handle string ID conversion and pass in test env
      assert changeset.valid?
    end
  end

  describe "schedule validation" do
    test "validates cron format" do
      data_source = Factory.insert!(:data_source)
      
      params = %{
        "name" => "Test Alert",
        "context" => "test",
        "description" => "Test description",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "schedule" => "invalid cron"
      }
      
      changeset = Alert.new_changeset(params)
      
      assert Keyword.has_key?(changeset.errors, :schedule)
      {error_msg, _} = changeset.errors[:schedule]
      assert error_msg =~ "scheduler format is wrong"
    end
    
    test "accepts valid cron format" do
      data_source = Factory.insert!(:data_source)
      
      params = %{
        "name" => "Test Alert", 
        "context" => "test",
        "description" => "Test description",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "schedule" => "0 9 * * 1"  # Every Monday at 9 AM
      }
      
      changeset = Alert.new_changeset(params)
      refute Keyword.has_key?(changeset.errors, :schedule)
    end
    
    test "accepts empty schedule for manual execution" do
      data_source = Factory.insert!(:data_source)
      
      params = %{
        "name" => "Test Alert",
        "context" => "test", 
        "description" => "Test description",
        "query" => "SELECT 1",
        "data_source_id" => data_source.id,
        "schedule" => ""  # Empty for manual
      }
      
      changeset = Alert.new_changeset(params)
      refute Keyword.has_key?(changeset.errors, :schedule)
    end
  end

  describe "required field validation" do
    test "requires all mandatory fields" do
      changeset = Alert.new_changeset(%{})
      
      required_fields = [:name, :description, :context, :query, :data_source_id]
      for field <- required_fields do
        assert Keyword.has_key?(changeset.errors, field)
      end
    end
    
    test "data_source_id is required" do
      params = %{
        "name" => "Test Alert",
        "context" => "test", 
        "description" => "Test description",
        "query" => "SELECT 1"
        # Missing data_source_id
      }
      
      changeset = Alert.new_changeset(params)
      assert Keyword.has_key?(changeset.errors, :data_source_id)
    end
  end
end
defmodule Alerts.Integration.DataSourceTest do
  use Alerts.DataCase
  
  alias Alerts.Business.DataSources
  alias Alerts.Business.DB.DataSource
  
  @moduletag :integration

  describe "data source integration" do
    test "data source creation with password encryption" do
      params = %{
        "name" => "encrypted_test_db",
        "display_name" => "Encrypted Test Database",
        "driver" => "MySQL ODBC 8.0 Unicode Driver",
        "server" => "localhost", 
        "database" => "test_db",
        "username" => "test_user",
        "password" => "secret_password_123",
        "port" => 3306,
        "additional_params" => ~s|{"CHARSET": "UTF8"}|
      }
      
      {:ok, data_source} = DataSources.create_data_source(params)
      
      # Verify basic fields
      assert data_source.name == "encrypted_test_db"
      assert data_source.display_name == "Encrypted Test Database"
      assert data_source.driver == "MySQL ODBC 8.0 Unicode Driver"
      assert data_source.server == "localhost"
      assert data_source.database == "test_db"
      assert data_source.username == "test_user"
      assert data_source.port == 3306
      
      # Password should be encrypted (not the original)
      assert data_source.password != "secret_password_123"
      assert is_binary(data_source.password)
      assert String.length(data_source.password) > 0
      
      # Additional params should be parsed JSON
      assert data_source.additional_params == %{"CHARSET" => "UTF8"}
      
      # Verify we can retrieve it from database
      found_ds = Alerts.Repo.get!(DataSource, data_source.id)
      assert found_ds.name == "encrypted_test_db"
      assert found_ds.password == data_source.password  # Still encrypted
    end

    test "data source deletion with dependency checking" do
      # Create data source
      data_source = Alerts.Factory.insert!(:data_source, name: "deletable_db")
      
      # Should be able to delete when no alerts use it
      {:ok, deleted} = DataSources.delete_data_source(data_source)
      assert deleted.id == data_source.id
      
      # Should not exist in database anymore
      refute Alerts.Repo.get(DataSource, data_source.id)
    end

    test "data source deletion blocked when alerts depend on it" do
      # Create data source and alert that uses it
      data_source = Alerts.Factory.insert!(:data_source, name: "in_use_db")
      Alerts.Factory.insert!(:alert, data_source_id: data_source.id)
      
      # Deletion should fail
      {:error, message} = DataSources.delete_data_source(data_source)
      assert message =~ "Cannot delete data source"
      assert message =~ "in_use_db"
      assert message =~ "1 alert(s) are still using it"
      
      # Data source should still exist
      assert Alerts.Repo.get(DataSource, data_source.id)
    end

    test "data source usage statistics" do
      # Create multiple data sources
      ds1 = Alerts.Factory.insert!(:data_source, name: "popular_db")
      _ds2 = Alerts.Factory.insert!(:data_source, name: "unused_db")
      ds3 = Alerts.Factory.insert!(:data_source, name: "single_use_db")
      
      # Create alerts using some data sources
      Alerts.Factory.insert!(:alert, data_source_id: ds1.id)
      Alerts.Factory.insert!(:alert, data_source_id: ds1.id)
      Alerts.Factory.insert!(:alert, data_source_id: ds1.id)  # 3 alerts
      Alerts.Factory.insert!(:alert, data_source_id: ds3.id)  # 1 alert
      # ds2 has no alerts
      
      # Get usage statistics
      stats = DataSources.get_data_source_usage_stats()
      
      assert stats["popular_db"] == 3
      assert stats["single_use_db"] == 1
      assert Map.get(stats, "unused_db", 0) == 0  # Should not appear or be 0
    end

    test "ODBC connection string building" do
      # Test with map parameters
      map_params = %{
        "DRIVER" => "MySQL ODBC 8.0 Unicode Driver",
        "SERVER" => "localhost",
        "DATABASE" => "test_db", 
        "USER" => "test_user",
        "PASSWORD" => "test_pass",
        "PORT" => "3306"
      }
      
      result = DataSources.build_odbc_string(map_params)
      assert is_list(result)  # Should return charlist
      
      result_string = List.to_string(result)
      assert result_string =~ "DRIVER=MySQL ODBC 8.0 Unicode Driver"
      assert result_string =~ "SERVER=localhost"
      assert result_string =~ "DATABASE=test_db"
      assert result_string =~ "USER=test_user"
      assert result_string =~ "PASSWORD=test_pass"
      assert result_string =~ "PORT=3306"
      
      # Test with keyword list
      keyword_params = [
        DRIVER: "PostgreSQL Unicode",
        SERVER: "pg.example.com",
        PORT: "5432"
      ]
      
      result2 = DataSources.build_odbc_string(keyword_params)
      result2_string = List.to_string(result2)
      assert result2_string =~ "DRIVER=PostgreSQL Unicode"
      assert result2_string =~ "SERVER=pg.example.com"
      assert result2_string =~ "PORT=5432"
    end

    test "data source connection validation" do
      # Test with invalid params (should fail validation first)
      invalid_params = %{"name" => "", "port" => "not_a_number"}
      
      {:error, message} = DataSources.test_connection_params(invalid_params)
      assert message == "Invalid data source parameters"
      
      # Test with valid params but non-existent server (would require actual ODBC)
      # In test environment this should be skipped
      valid_params = %{
        "name" => "test_connection_db",
        "display_name" => "Connection Test DB", 
        "driver" => "MySQL ODBC 8.0 Unicode Driver",
        "server" => "nonexistent.server.com",
        "database" => "test_db",
        "username" => "test_user",
        "password" => "test_pass",
        "port" => 3306,
        "additional_params" => "{}"
      }
      
      # In test environment, this should not actually try to connect
      # The function should handle test environment gracefully
      result = DataSources.test_connection_params(valid_params)
      # Should either succeed (skipped in test) or fail gracefully
      assert result in [{:ok, "Connection test skipped in test environment"}, 
                        {:error, "Connection test not available in test environment"}] or
             (is_tuple(result) and elem(result, 0) == :error)
    end
  end
end
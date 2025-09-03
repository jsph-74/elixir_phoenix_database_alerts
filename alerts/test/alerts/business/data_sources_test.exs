defmodule Alerts.Business.DataSourcesTest do
  use Alerts.DataCase

  alias Alerts.Business.DataSources
  alias Alerts.Business.DB.DataSource
  alias Alerts.Factory

  describe "create_data_source/1" do
    test "creates data source with valid params" do
      params = %{
        "name" => "test_db",
        "display_name" => "Test Database",
        "driver" => "MySQL ODBC 8.0 Unicode Driver",
        "server" => "localhost",
        "database" => "test_db",
        "username" => "user",
        "password" => "pass",
        "port" => 3306,
        "additional_params" => "{}"
      }

      assert {:ok, data_source} = DataSources.create_data_source(params)
      assert data_source.name == "test_db"
      assert data_source.display_name == "Test Database"
      assert data_source.port == 3306
    end

    test "returns error with invalid params" do
      params = %{"name" => ""}  # Missing required fields

      assert {:error, changeset} = DataSources.create_data_source(params)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end

    test "parses JSON additional_params" do
      params = %{
        "name" => "test_db",
        "display_name" => "Test Database",
        "driver" => "MySQL ODBC 8.0 Unicode Driver",
        "server" => "localhost",
        "database" => "test_db",
        "username" => "user",
        "port" => 3306,
        "additional_params" => ~s|{"CHARSET": "UTF8", "SSL": "true"}|
      }

      assert {:ok, data_source} = DataSources.create_data_source(params)
      assert data_source.additional_params == %{"CHARSET" => "UTF8", "SSL" => "true"}
    end
  end


  describe "delete_data_source/1" do
    test "deletes data source when no alerts are using it" do
      data_source = Factory.insert!(:data_source)

      assert {:ok, deleted} = DataSources.delete_data_source(data_source)
      assert deleted.id == data_source.id

      # Should not exist anymore
      refute Alerts.Repo.get(DataSource, data_source.id)
    end

  end

  describe "build_odbc_string/1" do
    test "builds ODBC string from map parameters" do
      params = %{"DRIVER" => "MySQL", "SERVER" => "localhost", "PORT" => "3306"}

      result = DataSources.build_odbc_string(params)
      # Should be a charlist
      assert is_list(result)

      # Convert back to string for easier testing
      str = List.to_string(result)
      assert str =~ "DRIVER=MySQL"
      assert str =~ "SERVER=localhost"
      assert str =~ "PORT=3306"
    end

    test "builds ODBC string from keyword list parameters" do
      params = [DRIVER: "MySQL", SERVER: "localhost", PORT: "3306"]

      result = DataSources.build_odbc_string(params)
      assert is_list(result)

      str = List.to_string(result)
      assert str =~ "DRIVER=MySQL"
      assert str =~ "SERVER=localhost"
      assert str =~ "PORT=3306"
    end
  end

  describe "test_connection/1" do
    # Note: This would require mocking the ODBC module in a real implementation
    # For now, we'll skip actual connection testing as it requires external dependencies

    test "test_connection_params validates changeset first" do
      invalid_params = %{"name" => "", "port" => "invalid"}

      assert {:error, message} = DataSources.test_connection_params(invalid_params)
      assert message == "Invalid data source parameters"
    end
  end
end

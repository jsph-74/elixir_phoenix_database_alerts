defmodule Alerts.Business.DB.DataSourceChangesetTest do
  use Alerts.DataCase

  alias Alerts.Business.DB.DataSource
  alias Alerts.Factory


  describe "changeset/2 password handling" do
    test "preserves existing password when empty string provided" do
      data_source = Factory.insert!(:data_source, password: "original_password")

      # Update with empty password
      changeset = DataSource.changeset(data_source, %{"password" => "", "display_name" => "Updated"})

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :password)
      # Password should be encrypted, so decrypt it to verify
      encrypted_password = get_field(changeset, :password)
      assert Alerts.Encryption.decrypt(encrypted_password) == "original_password"
    end

    test "preserves existing password when nil provided" do
      data_source = Factory.insert!(:data_source, password: "original_password")

      # Update with nil password
      changeset = DataSource.changeset(data_source, %{"password" => nil, "display_name" => "Updated"})

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :password)
      # Password should be encrypted, so decrypt it to verify
      encrypted_password = get_field(changeset, :password)
      assert Alerts.Encryption.decrypt(encrypted_password) == "original_password"
    end

    test "updates password when valid string provided" do
      data_source = Factory.insert!(:data_source, password: "original_password")

      # Update with new password
      changeset = DataSource.changeset(data_source, %{"password" => "new_password", "display_name" => "Updated"})

      assert changeset.valid?
      assert Map.has_key?(changeset.changes, :password)
      # Password should be encrypted, so decrypt it to verify
      encrypted_password = get_field(changeset, :password)
      assert Alerts.Encryption.decrypt(encrypted_password) == "new_password"
    end

    test "handles password for new data source" do
      # New data source with password
      changeset = DataSource.changeset(%DataSource{}, %{
        "name" => "test_new",
        "display_name" => "Test New",
        "driver" => "MySQL ODBC 8.0 Unicode Driver",
        "server" => "localhost",
        "database" => "test",
        "username" => "user",
        "password" => "new_password",
        "port" => 3306
      })

      assert changeset.valid?
      # Password should be encrypted, so decrypt it to verify
      encrypted_password = get_field(changeset, :password)
      assert Alerts.Encryption.decrypt(encrypted_password) == "new_password"
    end
  end
end

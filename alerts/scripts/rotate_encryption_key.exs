# Encryption Key Rotation Script
# Usage: mix run scripts/rotate_encryption_key.exs NEW_KEY
#
# This script:
# 1. Reads current encryption key from mounted Docker secret
# 2. Fetches all data sources from the database
# 3. Decrypts passwords using the current key
# 4. Re-encrypts passwords using the NEW_KEY
# 5. Updates the database records
#
# IMPORTANT: Backup your database before running this script!

# Import the existing modules
import Ecto.Query, warn: false
alias Alerts.Repo
alias Alerts.Encryption
alias Alerts.Business.DB.DataSource

defmodule EncryptionRotation do
  @moduledoc """
  Handles rotation of encryption keys for data source passwords
  """

  def rotate_keys(new_key) do
    IO.puts("🔄 Starting encryption key rotation...")
    IO.puts("📊 Using existing database connection...")
    
    # Read current encryption key from mounted Docker secret
    old_key = File.read!("/run/secrets/data_source_encryption_key") |> String.trim()
    IO.puts("✅ Read current encryption key from Docker secret")

    # Fetch all data sources with non-empty passwords using existing Repo
    data_sources = Repo.all(
      from ds in DataSource,
      where: not is_nil(ds.password) and ds.password != "",
      select: {ds.id, ds.name, ds.password}
    )

    IO.puts("📋 Found #{length(data_sources)} data sources with passwords to rotate")


    # Rotate data source passwords
    data_source_results = Enum.map(data_sources, fn {id, name, encrypted_password} ->
      try do
        # Decrypt with old key using existing Encryption module
        plaintext_password = Encryption.decrypt_with_key(encrypted_password, old_key)

        # Encrypt with new key using existing Encryption module
        new_encrypted_password = Encryption.encrypt_with_key(plaintext_password, new_key)

        # Update database using existing Repo
        data_source = Repo.get!(DataSource, id)
        changeset = Ecto.Changeset.change(data_source, password: new_encrypted_password)
        {:ok, _} = Repo.update(changeset)

        IO.puts("✅ Rotated key for data source: #{name} (ID: #{id})")
        {:ok, :data_source, id, name}
      rescue
        error ->
          IO.puts("❌ Failed to rotate key for data source: #{name} (ID: #{id}) - #{inspect(error)}")
          {:error, :data_source, id, name, error}
      end
    end)

    results = data_source_results

    # Count results
    successes = Enum.count(results, fn
      {:ok, _, _, _} -> true
      _ -> false
    end)

    failures = Enum.count(results, fn
      {:error, _, _, _, _} -> true
      _ -> false
    end)

    # Count by type
    data_source_successes = Enum.count(results, fn
      {:ok, :data_source, _, _} -> true
      _ -> false
    end)

    IO.puts("\n🎯 Rotation Summary:")
    IO.puts("✅ Successfully rotated: #{data_source_successes} data sources")
    IO.puts("❌ Failed to rotate: #{failures} records")

    if failures == 0 do
      IO.puts("\n🎉 All encryption keys rotated successfully!")
      IO.puts("🔧 Don't forget to:")
      IO.puts("   1. Update your DATA_SOURCE_ENCRYPTION_KEY environment variable")
      IO.puts("   2. Restart your application")
      IO.puts("   3. Test data source connections")
      System.halt(0)
    else
      IO.puts("\n⚠️  Some rotations failed. Please check the errors above.")
      System.halt(1)
    end
  end
end

# Main execution
case System.argv() do
  [new_key] ->
    # Start the application to ensure Repo is available
    Application.ensure_all_started(:alerts)

    # No confirmation needed here - already confirmed in bash script
    EncryptionRotation.rotate_keys(new_key)

  _ ->
    IO.puts("Usage: elixir scripts/rotate_encryption_key.exs NEW_KEY")
    IO.puts("")
    IO.puts("Example:")
    IO.puts("  # Generate a new key first:")
    IO.puts("  NEW_KEY=$(openssl rand -base64 32)")
    IO.puts("  # Then rotate:")
    IO.puts("  elixir scripts/rotate_encryption_key.exs $NEW_KEY")
    System.halt(1)
end

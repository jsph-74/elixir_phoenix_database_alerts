#!/usr/bin/env elixir

# Migration Script for Existing Plaintext Passwords
# 
# This script encrypts any existing plaintext passwords in the database.
# Run this ONCE after setting up encryption for the first time.
#
# Usage: elixir scripts/migrate_existing_passwords.exs

Mix.install([
  {:ecto_sql, "~> 3.13"},
  {:postgrex, "~> 0.21"},
  {:jason, "~> 1.4"}
])

defmodule ExistingPasswordMigration do
  @moduledoc """
  Migrates existing plaintext passwords to encrypted format
  """

  def migrate_passwords do
    IO.puts("🔄 Starting migration of existing plaintext passwords...")
    
    # Check if encryption key is set
    encryption_key = System.get_env("DATA_SOURCE_ENCRYPTION_KEY")
    if is_nil(encryption_key) or encryption_key == "" do
      IO.puts("❌ Error: DATA_SOURCE_ENCRYPTION_KEY environment variable not set!")
      IO.puts("   Please set your encryption key first:")
      IO.puts("   export DATA_SOURCE_ENCRYPTION_KEY=$(openssl rand -base64 32)")
      System.halt(1)
    end

    IO.puts("📊 Connecting to database...")

    # Database configuration
    config = [
      hostname: System.get_env("DB_HOST", "localhost"),
      port: String.to_integer(System.get_env("DB_PORT", "5432")),
      username: System.get_env("DB_USER", "postgres"),
      password: System.get_env("DB_PASSWORD", "postgres"),
      database: System.get_env("DB_NAME", "alerts_dev"),
      pool_size: 1
    ]

    {:ok, pid} = Postgrex.start_link(config)
    
    # Fetch all data sources with non-empty passwords
    {:ok, %{rows: data_sources}} = Postgrex.query!(pid, """
      SELECT id, name, password FROM data_sources 
      WHERE password IS NOT NULL AND password != ''
    """, [])

    IO.puts("📋 Found #{length(data_sources)} data sources with passwords")

    if length(data_sources) == 0 do
      IO.puts("✅ No passwords to migrate - all done!")
      Postgrex.close(pid)
      return
    end

    IO.puts("🔍 Analyzing passwords to determine which need encryption...")

    {encrypted_passwords, plaintext_passwords} = 
      Enum.reduce(data_sources, {[], []}, fn [id, name, password], {encrypted, plaintext} ->
        if looks_encrypted?(password) do
          {[{id, name, password} | encrypted], plaintext}
        else
          {encrypted, [{id, name, password} | plaintext]}
        end
      end)

    IO.puts("📊 Analysis results:")
    IO.puts("   🔒 Already encrypted: #{length(encrypted_passwords)}")
    IO.puts("   🔓 Need encryption: #{length(plaintext_passwords)}")

    if length(plaintext_passwords) == 0 do
      IO.puts("✅ All passwords are already encrypted - nothing to do!")
      Postgrex.close(pid)
      return
    end

    IO.puts("\n⚠️  WARNING: This will encrypt #{length(plaintext_passwords)} plaintext passwords!")
    IO.puts("📋 Make sure you have a database backup before proceeding.")
    IO.write("Continue with migration? (y/N): ")
    
    response = IO.gets("") |> String.trim() |> String.downcase()
    
    unless response in ["y", "yes"] do
      IO.puts("❌ Migration cancelled.")
      Postgrex.close(pid)
      System.halt(0)
    end

    # Encrypt plaintext passwords
    results = Enum.map(plaintext_passwords, fn {id, name, plaintext_password} ->
      try do
        # Encrypt the password
        encrypted_password = encrypt_password(plaintext_password, encryption_key)
        
        # Update database
        {:ok, _} = Postgrex.query!(pid, """
          UPDATE data_sources SET password = $1 WHERE id = $2
        """, [encrypted_password, id])

        IO.puts("✅ Encrypted password for data source: #{name} (ID: #{id})")
        {:ok, id, name}
      rescue
        error ->
          IO.puts("❌ Failed to encrypt password for data source: #{name} (ID: #{id}) - #{inspect(error)}")
          {:error, id, name, error}
      end
    end)

    # Count results
    successes = Enum.count(results, fn {status, _, _} -> status == :ok end)
    failures = Enum.count(results, fn 
      {status, _, _, _} -> status == :error
      _ -> false
    end)

    IO.puts("\n🎯 Migration Summary:")
    IO.puts("✅ Successfully encrypted: #{successes} passwords")
    IO.puts("❌ Failed to encrypt: #{failures} passwords")

    if failures == 0 do
      IO.puts("\n🎉 All passwords migrated successfully!")
      IO.puts("🔧 Next steps:")
      IO.puts("   1. Test your data source connections")
      IO.puts("   2. Create a backup with encrypted passwords")
      IO.puts("   3. Document your encryption key securely")
    else
      IO.puts("\n⚠️  Some migrations failed. Please check the errors above.")
      System.halt(1)
    end

    Postgrex.close(pid)
  end

  # Check if a password looks like it's already encrypted
  # Encrypted passwords are base64 encoded and much longer than typical passwords
  defp looks_encrypted?(password) do
    # Encrypted passwords are base64 encoded and typically 60+ characters
    # They also contain only base64 characters (A-Z, a-z, 0-9, +, /, =)
    String.length(password) > 50 and Regex.match?(~r/^[A-Za-z0-9+\/=]+$/, password)
  end

  # Encryption function (copied from main app for standalone use)
  defp encrypt_password(plaintext, key) when is_binary(plaintext) and is_binary(key) do
    decoded_key = Base.decode64!(key)
    iv = :crypto.strong_rand_bytes(16)
    aad = "alerts_data_source"
    
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, decoded_key, iv, plaintext, aad, true)
    (iv <> tag <> ciphertext) |> Base.encode64()
  end
end

# Main execution
IO.puts("🔐 Data Source Password Migration Tool")
IO.puts("=====================================")
ExistingPasswordMigration.migrate_passwords()
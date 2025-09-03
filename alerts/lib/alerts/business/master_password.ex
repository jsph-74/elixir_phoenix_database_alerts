defmodule Alerts.Business.MasterPassword do
  @moduledoc """
  Master Password management for application security.
  """

  import Ecto.Query
  alias Alerts.Repo
  alias Alerts.Business.DB.AppSecurity
  alias Alerts.Encryption

  @master_password_key "master_password"

  @doc """
  Sets up a master password by encrypting and storing it in the database.
  """
  def setup_master_password(plain_password) do
    # Hash the password before encrypting
    password_hash = :crypto.hash(:sha256, plain_password) |> Base.encode64()
    
    # Encrypt the hash using the existing encryption key
    encrypted_password = Encryption.encrypt(password_hash)
    
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    attrs = %{
      key_type: @master_password_key,
      encrypted_value: encrypted_password,
      created_at: now,
      last_changed: now
    }

    # Delete existing master password if it exists
    Repo.delete_all(from a in AppSecurity, where: a.key_type == ^@master_password_key)
    
    # Insert new master password
    %AppSecurity{}
    |> AppSecurity.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Validates a master password against the stored encrypted version.
  Returns {:ok, :valid} or {:error, :invalid}
  """
  def validate_master_password(plain_password) do
    case get_master_password_record() do
      nil ->
        {:ok, :no_password_set}
        
      record ->
        # Hash the provided password
        provided_hash = :crypto.hash(:sha256, plain_password) |> Base.encode64()
        
        # Decrypt the stored hash
        try do
          stored_hash = Encryption.decrypt(record.encrypted_value)
          if provided_hash == stored_hash do
            {:ok, :valid}
          else
            {:error, :invalid}
          end
        rescue
          _error ->
            {:error, :decryption_failed}
        end
    end
  end

  @doc """
  Checks if a master password is configured.
  """
  def master_password_configured? do
    get_master_password_record() != nil
  end

  @doc """
  Removes the master password configuration.
  """
  def remove_master_password do
    Repo.delete_all(from a in AppSecurity, where: a.key_type == ^@master_password_key)
  end

  defp get_master_password_record do
    Repo.one(from a in AppSecurity, where: a.key_type == ^@master_password_key)
  end
end
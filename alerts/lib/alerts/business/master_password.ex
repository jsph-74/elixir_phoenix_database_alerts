defmodule Alerts.Business.MasterPassword do
  @moduledoc """
  Master Password management using Docker secrets for application security.
  """

  require Logger

  @master_password_secret_path "/run/secrets/master_password"

  @doc """
  Validates a master password against the stored Docker secret.
  Returns {:ok, :valid}, {:ok, :no_password_set}, or {:error, :invalid}
  """
  def validate_master_password(plain_password) when is_binary(plain_password) do
    case read_master_password_secret() do
      {:ok, stored_hash} ->
        # Hash the provided password with SHA-256
        provided_hash = :crypto.hash(:sha256, plain_password) |> Base.encode16(case: :lower)
        
        if provided_hash == String.trim(stored_hash) do
          {:ok, :valid}
        else
          {:error, :invalid}
        end
        
      {:error, :not_configured} ->
        {:ok, :no_password_set}
        
      {:error, reason} ->
        Logger.error("Failed to read master password secret: #{inspect(reason)}")
        {:error, :secret_read_failed}
    end
  end

  def validate_master_password(_), do: {:error, :invalid}

  @doc """
  Checks if a master password is configured via Docker secrets.
  """
  def master_password_configured? do
    case read_master_password_secret() do
      {:ok, hash} when is_binary(hash) and hash != "" -> true
      _ -> false
    end
  end

  # Reads the master password hash from Docker secrets.
  # Returns {:ok, hash} or {:error, reason}
  defp read_master_password_secret do
    if File.exists?(@master_password_secret_path) do
      case File.read(@master_password_secret_path) do
        {:ok, content} when content != "" ->
          {:ok, String.trim(content)}
          
        {:ok, ""} ->
          {:error, :empty_secret}
          
        {:error, reason} ->
          {:error, {:file_read_error, reason}}
      end
    else
      {:error, :not_configured}
    end
  end
end
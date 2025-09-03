defmodule Alerts.Encryption do
  @moduledoc """
  Handles encryption/decryption of sensitive data using AES-256-GCM
  """

  # Get encryption key from environment variable (runtime)
  defp get_encryption_key do
    case Application.get_env(:alerts, :encryption_key) || System.get_env("DATA_SOURCE_ENCRYPTION_KEY") do
      nil -> raise "DATA_SOURCE_ENCRYPTION_KEY environment variable not set"
      key -> key
    end
  end

  @doc """
  Encrypts a plaintext string using AES-256-GCM
  Returns base64-encoded encrypted data with IV prepended
  """
  def encrypt(nil), do: nil
  def encrypt(""), do: ""

  def encrypt(plaintext) when is_binary(plaintext) do
    key = decode_key(get_encryption_key())
    iv = :crypto.strong_rand_bytes(16)  # 128-bit IV for GCM
    aad = "alerts_data_source"  # Additional authenticated data
    
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)
    
    # Prepend IV and tag to ciphertext, then base64 encode
    (iv <> tag <> ciphertext) |> Base.encode64()
  end

  @doc """
  Decrypts base64-encoded encrypted data
  """
  def decrypt(nil), do: nil
  def decrypt(""), do: ""

  def decrypt(encrypted_data) when is_binary(encrypted_data) do
    key = decode_key(get_encryption_key())
    
    # Decode base64 and extract IV, tag, and ciphertext
    data = Base.decode64!(encrypted_data)
    <<iv::binary-16, tag::binary-16, ciphertext::binary>> = data
    aad = "alerts_data_source"
    
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, aad, tag, false) do
      :error -> 
        raise "Failed to decrypt data - invalid key or corrupted data"
      plaintext -> 
        plaintext
    end
  end

  @doc """
  Generates a new 32-byte (256-bit) encryption key
  """
  def generate_key do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  # Private helper to decode the key from base64
  defp decode_key(key_string) do
    case Base.decode64(key_string) do
      {:ok, key} when byte_size(key) == 32 -> key
      {:ok, _} -> raise "Encryption key must be 32 bytes (256 bits)"
      :error -> raise "Invalid base64 encryption key"
    end
  end

  @doc """
  Encrypts data with a specific key (used for rotation)
  """
  def encrypt_with_key(plaintext, key) when is_binary(plaintext) and is_binary(key) do
    decoded_key = decode_key(key)
    iv = :crypto.strong_rand_bytes(16)
    aad = "alerts_data_source"
    
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, decoded_key, iv, plaintext, aad, true)
    (iv <> tag <> ciphertext) |> Base.encode64()
  end

  @doc """
  Decrypts data with a specific key (used for rotation)
  """
  def decrypt_with_key(encrypted_data, key) when is_binary(encrypted_data) and is_binary(key) do
    decoded_key = decode_key(key)
    data = Base.decode64!(encrypted_data)
    <<iv::binary-16, tag::binary-16, ciphertext::binary>> = data
    aad = "alerts_data_source"
    
    case :crypto.crypto_one_time_aead(:aes_256_gcm, decoded_key, iv, ciphertext, aad, tag, false) do
      :error -> raise "Failed to decrypt data with provided key"
      plaintext -> plaintext
    end
  end
end
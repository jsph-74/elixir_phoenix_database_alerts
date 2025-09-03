defmodule Alerts.Business.DB.DataSource do
  use Ecto.Schema
  import Ecto.Changeset
  alias Alerts.Encryption

  @primary_key {:id, :id, autogenerate: true}
  schema "data_sources" do
    field :name, :string
    field :display_name, :string
    field :driver, :string
    field :server, :string
    field :database, :string
    field :username, :string
    field :password, :string
    field :port, :integer
    field :additional_params, :map, default: %{}
    
    timestamps()
  end

  @doc false
  def changeset(data_source, attrs) do
    # Remove empty password to preserve existing one (handle both string and atom keys)
    attrs = case Map.get(attrs, "password") || Map.get(attrs, :password) do
      pwd when pwd in ["", nil] -> 
        attrs |> Map.delete("password") |> Map.delete(:password)
      _ -> attrs
    end
    
    data_source
    |> cast(attrs, [:name, :display_name, :driver, :server, :database, :username, :password, :port])
    |> parse_additional_params(attrs)
    |> encrypt_password()
    |> validate_required([:name, :display_name, :driver, :server, :database, :username, :port])
    |> unique_constraint(:name)
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_number(:port, greater_than: 0, less_than: 65536)
  end


  defp parse_additional_params(changeset, attrs) do
    case Map.get(attrs, "additional_params") || Map.get(attrs, :additional_params) do
      nil -> changeset
      "" -> put_change(changeset, :additional_params, %{})
      "{}" -> put_change(changeset, :additional_params, %{})
      json_string when is_binary(json_string) ->
        case Jason.decode(json_string) do
          {:ok, params} when is_map(params) ->
            put_change(changeset, :additional_params, params)
          {:error, _} ->
            add_error(changeset, :additional_params, "must be valid JSON")
        end
      params when is_map(params) -> 
        put_change(changeset, :additional_params, params)
      _ -> 
        add_error(changeset, :additional_params, "must be a JSON object")
    end
  end

  @doc """
  Creates an ODBC connection string from a DataSource struct
  Automatically decrypts the password for ODBC use
  """
  def to_odbc_params(%__MODULE__{} = data_source) do
    decrypted_password = get_decrypted_password(data_source)
    
    %{
      "DRIVER" => data_source.driver,
      "SERVER" => data_source.server,
      "DATABASE" => data_source.database,
      "UID" => data_source.username,
      "PORT" => to_string(data_source.port)
    }
    |> Map.merge(if decrypted_password, do: %{"PWD" => decrypted_password}, else: %{})
    |> Map.merge(data_source.additional_params || %{})
  end

  @doc """
  Gets the decrypted password for a data source
  """
  def get_decrypted_password(%__MODULE__{password: nil}), do: nil
  def get_decrypted_password(%__MODULE__{password: ""}), do: ""
  def get_decrypted_password(%__MODULE__{password: encrypted_password}) do
    Encryption.decrypt(encrypted_password)
  end

  @doc """
  Gets a masked password for display purposes
  """
  def get_masked_password(%__MODULE__{password: nil}), do: nil
  def get_masked_password(%__MODULE__{password: ""}), do: ""
  def get_masked_password(%__MODULE__{password: _encrypted_password}) do
    "••••••••••••"  # Show 12 masked characters
  end

  # Private function to encrypt password during changeset
  defp encrypt_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset  # No password change
      password -> put_change(changeset, :password, Encryption.encrypt(password))
    end
  end
end
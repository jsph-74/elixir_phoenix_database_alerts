defmodule Alerts.Business.DataSources do
  @moduledoc """
  Business logic for managing data source configurations
  """

  import Ecto.Query
  alias Alerts.Repo
  alias Alerts.Business.DB.{DataSource, Alert}
  alias Alerts.Business.Odbc

  @doc """
  Returns the list of all data sources
  """
  def list_data_sources do
    DataSource
    |> order_by(:name)
    |> Repo.all()
  end

  @doc """
  Gets a single data source by ID
  """
  def get_data_source!(id), do: Repo.get!(DataSource, id)

  @doc """
  Gets ODBC connection string for a data source by ID (preferred method)
  """
  def get_odbcstring_by_id(data_source_id) when is_integer(data_source_id) do
    data_source = get_data_source!(data_source_id)

    DataSource.to_odbc_params(data_source)
    |> build_odbc_string()
  end

  @doc """
  Creates a data source
  """
  def create_data_source(attrs \\ %{}) do
    %DataSource{}
    |> DataSource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a data source
  """
  def update_data_source(%DataSource{} = data_source, attrs) do
    data_source
    |> DataSource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a data source if no alerts are using it
  """
  def delete_data_source(%DataSource{} = data_source) do
    case count_alerts_using_data_source_id(data_source.id) do
      0 ->
        # Safe to delete permanently
        Repo.delete(data_source)

      count ->
        {:error, "Cannot delete data source '#{data_source.name}' because #{count} alert(s) are still using it"}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data source changes
  """
  def change_data_source(%DataSource{} = data_source, attrs \\ %{}) do
    DataSource.changeset(data_source, attrs)
  end

  @doc """
  Tests connection to a data source
  """
  def test_connection(%DataSource{} = data_source) do
    test_query = "SELECT 1"
    odbc_params = DataSource.to_odbc_params(data_source)

    # Run connection test with 10-second timeout
    task = Task.async(fn ->
      Odbc.run_query_odbc_connection_string(:erlang.binary_to_list(test_query), build_odbc_string(odbc_params))
    end)

    case Task.yield(task, 10_000) do
      {:ok, {:selected, _, _}} ->
        {:ok, "Connection successful"}
      {:ok, {:error, message}} ->
        {:error, message}
      {:ok, _} ->
        {:error, "Unknown connection error"}
      nil ->
        # Timeout occurred
        Task.shutdown(task, :brutal_kill)
        {:error, "Connection timeout after 10 seconds"}
    end
  end

  @doc """
  Tests connection using parameters (before saving)
  """
  def test_connection_params(attrs) do
    changeset = DataSource.changeset(%DataSource{}, attrs)

    if changeset.valid? do
      data_source = Ecto.Changeset.apply_changes(changeset)
      test_connection(data_source)
    else
      {:error, "Invalid data source parameters"}
    end
  end

  @doc """
  Tests connection for existing data source with form parameters
  Handles password field correctly - uses existing encrypted password if form field is empty
  """
  def test_connection_with_form_params(%DataSource{} = existing_data_source, form_params) do
    # Get the plaintext password to use for testing
    plaintext_password = case Map.get(form_params, "password") do
      pwd when pwd in ["", nil] ->
        # Use existing decrypted password if form field is empty
        DataSource.get_decrypted_password(existing_data_source)
      pwd ->
        # Use new plaintext password from form
        pwd
    end

    # Build ODBC connection parameters directly (bypass DataSource struct)
    odbc_params = %{
      "DRIVER" => Map.get(form_params, "driver", existing_data_source.driver),
      "SERVER" => Map.get(form_params, "server", existing_data_source.server),
      "DATABASE" => Map.get(form_params, "database", existing_data_source.database),
      "UID" => Map.get(form_params, "username", existing_data_source.username),
      "PORT" => case Map.get(form_params, "port", existing_data_source.port) do
        port when is_binary(port) -> port
        port when is_integer(port) -> to_string(port)
      end
    }
    |> Map.merge(if plaintext_password, do: %{"PWD" => plaintext_password}, else: %{})
    |> Map.merge(existing_data_source.additional_params || %{})

    # Run connection test directly with ODBC params
    test_query = "SELECT 1"

    task = Task.async(fn ->
      Odbc.run_query_odbc_connection_string(:erlang.binary_to_list(test_query), build_odbc_string(odbc_params))
    end)

    case Task.yield(task, 10_000) do
      {:ok, {:selected, _, _}} ->
        {:ok, "Connection successful"}
      {:ok, {:error, message}} ->
        {:error, message}
      {:ok, _} ->
        {:error, "Unknown connection error"}
      nil ->
        # Timeout occurred
        Task.shutdown(task, :brutal_kill)
        {:error, "Connection timeout after 10 seconds"}
    end
  end

  @doc """
  Counts how many current alerts are using a data source by ID (more efficient)
  """
  def count_alerts_using_data_source_id(nil), do: 0

  def count_alerts_using_data_source_id(data_source_id) do
    Alert
    |> where([a], a.data_source_id == ^data_source_id and a.lifecycle_status == "current")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets usage statistics for all data sources
  """
  def get_data_source_usage_stats do
    query = from a in Alert,
      join: ds in DataSource, on: a.data_source_id == ds.id,
      where: a.lifecycle_status == "current",
      group_by: ds.name,
      select: {ds.name, count(a.id)}

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Builds ODBC connection string from parameters map
  """
  def build_odbc_string(params) when is_map(params) do
    params
    |> Enum.reduce([], fn {k, v}, acc -> acc ++ ["#{k}=#{v}"] end)
    |> Enum.join(";")
    |> String.to_charlist()
  end

  def build_odbc_string(params) when is_list(params) do
    params
    |> Enum.reduce([], fn {k, v}, acc -> acc ++ ["#{k}=#{v}"] end)
    |> Enum.join(";")
    |> String.to_charlist()
  end
end

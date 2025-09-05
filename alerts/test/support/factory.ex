defmodule Alerts.Factory do
  @moduledoc """
  Simple factory for creating test data
  """

  alias Alerts.Business.DB.{Alert, DataSource}
  alias Alerts.Repo

  def build(:data_source) do
    unique_id = :rand.uniform(999999)
    %DataSource{
      name: "test_source_#{unique_id}",
      display_name: "Test Data Source #{unique_id}",
      driver: "MariaDB Unicode",
      server: "host.docker.internal",
      database: "test",
      username: "root",
      password: "mysql",
      port: 3306,
      additional_params: %{}
    }
  end

  def build(:alert) do
    unique_id = :rand.uniform(999999)
    alias Alerts.Business.DB.Alert
    %Alert{
      name: "Test Alert #{unique_id}",
      description: "Test description #{unique_id}",
      query: "SELECT 1",
      context: "test_#{unique_id}",
      threshold: 0,
      schedule: nil,
      status: "never run",
      alert_public_id: Ecto.UUID.generate(),
      lifecycle_status: "current"
    }
  end

  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end

  def insert!(factory_name, attributes \\ [])

  def insert!(:alert, attributes) do
    # First create a data source if not provided
    data_source =
      if Keyword.has_key?(attributes, :data_source_id) do
        nil  # Data source already provided
      else
        insert!(:data_source)
      end

    # Generate random test data
    unique_id = :rand.uniform(999999)
    
    # Start with sensible defaults - use string keys like web forms
    defaults = %{
      "name" => "Test Alert #{unique_id}",
      "description" => "Test description #{unique_id}", 
      "query" => "SELECT 1",
      "context" => "test_#{unique_id}"
    }
    
    # Add data source if we created one
    defaults = if data_source, do: Map.put(defaults, "data_source_id", data_source.id), else: defaults
    
    # Convert attributes from keyword list to map with string keys
    attr_map = attributes 
    |> Enum.into(%{})
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
    
    # Merge with what the test wants to override
    attrs = Map.merge(defaults, attr_map)
    
    # Use real app logic
    case Alerts.Business.Alerts.create(attrs) do
      {:ok, alert} -> alert
      {:error, changeset} -> 
        raise "Factory failed to create alert: #{inspect(changeset.errors)}"
    end
  end

  def insert!(factory_name, attributes) do
    case factory_name do
      :data_source ->
        # Use changeset for data sources to ensure password encryption
        attrs = build(factory_name, attributes) |> Map.from_struct()
        changeset = DataSource.changeset(%DataSource{}, attrs)
        Repo.insert!(changeset)
      _ ->
        factory_name |> build(attributes) |> Repo.insert!()
    end
  end
end

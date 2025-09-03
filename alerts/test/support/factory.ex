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
      server: "test_mysql",
      database: "test",
      username: "monitor_user",
      password: "monitor_pass",
      port: 3306,
      additional_params: %{}
    }
  end

  def build(:alert) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %Alert{
      name: "Test Alert",
      context: "test_context",
      description: "Test description",
      query: "SELECT 1",
      data_source_id: nil,  # Will be set when we insert the data source
      threshold: 0,
      schedule: nil,
      status: "never run",
      results_size: 0,
      alert_public_id: Ecto.UUID.generate(),
      lifecycle_status: "current",
      inserted_at: now,
      updated_at: now
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

    # Build the alert and set the data source relationship
    alert = build(:alert, attributes)
    alert = if data_source, do: %{alert | data_source_id: data_source.id}, else: alert

    Repo.insert!(alert)
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

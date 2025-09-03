defmodule AlertsWeb.DataSourceController do
  use AlertsWeb, :controller
  
  import Ecto.Changeset, only: [get_change: 2, put_change: 3]
  
  alias Alerts.Business.DataSources
  alias Alerts.Business.DB.DataSource

  # Helper function to get database drivers from config
  defp get_database_drivers do
    Application.get_env(:alerts, :database_drivers, [])
  end

  def index(conn, _params) do
    data_sources = DataSources.list_data_sources()
    usage_stats = DataSources.get_data_source_usage_stats()
    
    render(conn, "index.html", data_sources: data_sources, usage_stats: usage_stats)
  end

  def show(conn, %{"id" => id}) do
    try do
      data_source = DataSources.get_data_source!(id)
      alert_count = DataSources.count_alerts_using_data_source_id(data_source.id)
      
      render(conn, "show.html", data_source: data_source, alert_count: alert_count)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def new(conn, _params) do
    # Create data source with JSON string for form display
    data_source_for_form = %DataSource{additional_params: "{}"}
    changeset = DataSources.change_data_source(data_source_for_form)
    database_drivers = get_database_drivers()
    render(conn, "new.html", changeset: changeset, database_drivers: database_drivers)
  end

  def create(conn, %{"data_source" => data_source_params}) do
    case DataSources.create_data_source(data_source_params) do
      {:ok, data_source} ->
        conn
        |> put_flash(:info, "Data source '#{data_source.display_name}' created successfully.")
        |> redirect(to: ~p"/data_sources")

      {:error, %Ecto.Changeset{} = changeset} ->
        # Convert any map values back to JSON strings for form re-display
        changeset = case get_change(changeset, :additional_params) do
          params when is_map(params) ->
            put_change(changeset, :additional_params, Jason.encode!(params))
          _ -> changeset
        end
        
        database_drivers = get_database_drivers()
        render(conn, "new.html", changeset: changeset, database_drivers: database_drivers)
    end
  end

  def edit(conn, %{"id" => id}) do
    try do
      data_source = DataSources.get_data_source!(id)
      
      # Convert map to JSON string for form display
      json_params = if data_source.additional_params && map_size(data_source.additional_params) > 0 do
        Jason.encode!(data_source.additional_params)
      else
        "{}"
      end
      
      # Create changeset with JSON string for form
      data_source_for_form = %{data_source | additional_params: json_params}
      changeset = DataSources.change_data_source(data_source_for_form)
      
      alert_count = DataSources.count_alerts_using_data_source_id(data_source.id)
      database_drivers = get_database_drivers()
      render(conn, "edit.html", data_source: data_source, changeset: changeset, alert_count: alert_count, database_drivers: database_drivers)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def update(conn, %{"id" => id, "data_source" => data_source_params}) do
    try do
      data_source = DataSources.get_data_source!(id)

      case DataSources.update_data_source(data_source, data_source_params) do
        {:ok, data_source} ->
          conn
          |> put_flash(:info, "Data source '#{data_source.display_name}' updated successfully.")
          |> redirect(to: ~p"/data_sources/#{data_source}")

        {:error, %Ecto.Changeset{} = changeset} ->
          alert_count = DataSources.count_alerts_using_data_source_id(data_source.id)
          
          # Convert any map values back to JSON strings for form re-display
          changeset = case get_change(changeset, :additional_params) do
            params when is_map(params) ->
              put_change(changeset, :additional_params, Jason.encode!(params))
            _ -> changeset
          end
          
          database_drivers = get_database_drivers()
          render(conn, "edit.html", data_source: data_source, changeset: changeset, alert_count: alert_count, database_drivers: database_drivers)
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def delete(conn, %{"id" => id}) do
    try do
      data_source = DataSources.get_data_source!(id)

      case DataSources.delete_data_source(data_source) do
        {:ok, _data_source} ->
          conn
          |> put_flash(:info, "Data source '#{data_source.display_name}' deleted successfully.")
          |> redirect(to: ~p"/data_sources")
          
        {:error, message} ->
          conn
          |> put_flash(:error, message)
          |> redirect(to: ~p"/data_sources")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def test_connection(conn, %{"id" => id}) do
    try do
      data_source = DataSources.get_data_source!(id)
      
      # Check where the request came from to determine redirect and message format
      referer = get_req_header(conn, "referer") |> List.first()
      
      {redirect_to, success_msg_format, error_msg_format} = cond do
        referer && String.contains?(referer, "/edit") ->
          # From edit page - redirect back to edit with simple message
          {~p"/data_sources/#{data_source}/edit", fn msg -> msg end, fn msg -> "Connection failed: #{msg}" end}
        
        referer && String.contains?(referer, "/data_sources") && !String.contains?(referer, "/data_sources/#{data_source.id}") ->
          # From index page - redirect to index with data source name
          {~p"/data_sources", 
           fn _msg -> "Data source '#{data_source.display_name}' connection successful" end,
           fn msg -> "Data source '#{data_source.display_name}' connection failed: #{msg}" end}
        
        true ->
          # From show page or direct access - redirect to show page
          {~p"/data_sources/#{data_source}", fn msg -> msg end, fn msg -> "Connection failed: #{msg}" end}
      end
      
      case DataSources.test_connection(data_source) do
        {:ok, message} ->
          conn
          |> put_flash(:info, success_msg_format.(message))
          |> redirect(to: redirect_to)
          
        {:error, message} ->
          conn
          |> put_flash(:error, error_msg_format.(message))
          |> redirect(to: redirect_to)
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(AlertsWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def test_connection_params(conn, %{"data_source" => data_source_params}) do
    case DataSources.test_connection_params(data_source_params) do
      {:ok, message} ->
        json(conn, %{success: true, message: message})
        
      {:error, message} ->
        json(conn, %{success: false, message: message})
    end
  end

  def test_connection_ajax(conn, %{"data_source" => data_source_params}) do
    # Get the existing data source to use as base
    case Map.get(data_source_params, "id") do
      nil ->
        # No ID provided, test with just the form parameters (for new data sources)
        case DataSources.test_connection_params(data_source_params) do
          {:ok, message} ->
            json(conn, %{success: true, message: message})
            
          {:error, message} ->
            json(conn, %{success: false, message: message})
        end
        
      id_str ->
        require Logger
        Logger.info("Processing ID: #{inspect(id_str)}")
        
        try do
          # Convert string ID to integer
          id_str_trimmed = String.trim(to_string(id_str))
          Logger.info("Trimmed ID string: #{inspect(id_str_trimmed)}")
          
          id = case Integer.parse(id_str_trimmed) do
            {parsed_id, ""} -> 
              Logger.info("Successfully parsed ID: #{parsed_id}")
              parsed_id
            {parsed_id, remainder} -> 
              Logger.info("Parsed ID with remainder: #{parsed_id}, remainder: #{inspect(remainder)}")
              parsed_id
            :error -> 
              Logger.error("Integer.parse failed for: #{inspect(id_str_trimmed)}")
              raise ArgumentError, "Cannot parse ID as integer: #{inspect(id_str)}"
          end
          
          Logger.info("Looking up data source with ID: #{id}")
          data_source = DataSources.get_data_source!(id)
          Logger.info("Found data source: #{data_source.name}")
          
          Logger.info("Testing connection with form params")
          case DataSources.test_connection_with_form_params(data_source, data_source_params) do
            {:ok, message} ->
              Logger.info("Connection test successful: #{message}")
              json(conn, %{success: true, message: message})
              
            {:error, message} ->
              Logger.error("Connection test failed: #{message}")
              json(conn, %{success: false, message: message})
          end
        rescue
          e in Ecto.NoResultsError ->
            Logger.error("Data source not found with ID #{inspect(id_str)}: #{inspect(e)}")
            json(conn, %{success: false, message: "Data source not found"})
          e in ArgumentError ->
            Logger.error("Invalid data source ID #{inspect(id_str)}: #{inspect(e)}")
            json(conn, %{success: false, message: "Invalid data source ID"})
          e ->
            Logger.error("Unexpected error in test connection: #{inspect(e)}")
            json(conn, %{success: false, message: "Connection test failed: #{Exception.message(e)}"})
        end
    end
  end
end
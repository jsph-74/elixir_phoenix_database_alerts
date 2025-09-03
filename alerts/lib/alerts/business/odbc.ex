defmodule Alerts.Business.Odbc do
  require Logger

  @could_not_connect "Could not connect to your data source"
  @unknown_error "Unknown error, check your logs"
  @write_query "Write queries are not allowed"

  def get_odbcstring_by_id(data_source_id) do
    # New ID-based method - more efficient
    Alerts.Business.DataSources.get_odbcstring_by_id(data_source_id)
  end

  # Legacy get_odbcstring function removed - use get_odbcstring_by_id/1 instead

  def run_and_rollback(query, db_pid) do
    try do
      results = db_pid |> :odbc.sql_query(query)
      db_pid |> :odbc.commit(:rollback)
      results
    rescue
      _ ->
        db_pid |> :odbc.commit(:rollback)
        @unknown_error
    end
  end

  def connect(odbc_string), do: odbc_string |> :odbc.connect(auto_commit: :off)

  def run_query_odbc_connection_string(query, odbc_string) do
    case connect(odbc_string) do
      {:ok, db_pid} ->
        results = query |> run_and_rollback(db_pid)
        :odbc.disconnect(db_pid)
        results

      _ ->
        {:error, @could_not_connect}
    end
  end

  # New ID-based method (preferred)
  def run_query_by_data_source_id(query, data_source_id) when is_bitstring(query),
    do: query |> :erlang.binary_to_list() |> run_query_by_data_source_id(data_source_id)

  def run_query_by_data_source_id(query, data_source_id) do
    case run_query_odbc_connection_string(query, get_odbcstring_by_id(data_source_id)) do
      {:selected, c, r} ->
        {:ok, %{columns: c, rows: r} |> process_resultset()}

      {:updated, _n} ->
        {:error, @write_query}

      # Connection or SQL error
      {:error, reason} ->
        if reason == @could_not_connect do
          Logger.error("Could not connect to data source ID #{data_source_id}")
          {:error, @could_not_connect}
        else
          Logger.error("SQL query error for data source ID #{data_source_id}: #{inspect(reason)}")
          formatted_error = format_sql_error(reason)
          {:error, formatted_error}
        end

      _ ->
        {:error, @unknown_error}
    end
  end

  # Legacy run_query functions removed - use run_query_by_data_source_id/2 instead

  def convert_to_string_if_charlist(item) when is_list(item), do: :erlang.list_to_binary(item)
  def convert_to_string_if_charlist({{_year, _month, _day}, {_hour, _minute, _second}} = datetime_tuple), do: format_datetime_tuple(datetime_tuple)
  def convert_to_string_if_charlist({a, b, c} = tuple) when is_integer(a) and is_integer(b) and is_integer(c), do: format_generic_tuple(tuple)
  def convert_to_string_if_charlist(item), do: item

  defp format_generic_tuple({a, b, c}) when a > 1900 and b <= 12 and c <= 31, do: format_date_tuple({a, b, c})
  defp format_generic_tuple({a, b, c}) when a <= 24 and b <= 60 and c <= 60, do: format_time_tuple({a, b, c})
  defp format_generic_tuple(tuple), do: inspect(tuple)  # Fallback for ambiguous tuples

  defp format_datetime_tuple({{year, month, day}, {hour, minute, second}}) do
    "#{year}-#{String.pad_leading(to_string(month), 2, "0")}-#{String.pad_leading(to_string(day), 2, "0")} #{String.pad_leading(to_string(hour), 2, "0")}:#{String.pad_leading(to_string(minute), 2, "0")}:#{String.pad_leading(to_string(second), 2, "0")}"
  end

  defp format_date_tuple({year, month, day}) do
    "#{year}-#{String.pad_leading(to_string(month), 2, "0")}-#{String.pad_leading(to_string(day), 2, "0")}"
  end

  defp format_time_tuple({hour, minute, second}) do
    "#{String.pad_leading(to_string(hour), 2, "0")}:#{String.pad_leading(to_string(minute), 2, "0")}:#{String.pad_leading(to_string(second), 2, "0")}"
  end

  @doc """

  iex(5)> Alerts.Business.Odbc.process_rows([{'a', 1}, {:atom, 1.2}])
  [["a", 1], [:atom, 1.2]]

  """
  def process_rows(map) do
    map
    |> Enum.map(
      &(&1
        |> Tuple.to_list()
        |> Enum.map(fn item -> convert_to_string_if_charlist(item) end))
    )
  end

  @doc """

  iex> Alerts.Business.Odbc.process_columns(['a', 1, :atom, 1.2])
  ["a", 1, :atom, 1.2]

  """
  def process_columns(list) do
    list |> Enum.map(&convert_to_string_if_charlist(&1))
  end

  def process_resultset(r) do
    max_rows = Application.get_env(:alerts, :max_result_rows, 1000)
    total_rows = Enum.count(r.rows)
    limited_rows = Enum.take(r.rows, max_rows)
    
    %{
      columns: process_columns(r.columns),
      rows: process_rows(limited_rows),
      command: :select,
      messages: [],
      num_rows: Enum.count(limited_rows),
      total_rows: total_rows,
      is_truncated: total_rows > max_rows
    }
  end

  defp format_sql_error(reason) do
    error_detail = case reason do
      reason when is_binary(reason) -> reason
      reason when is_list(reason) -> :erlang.list_to_binary(reason)
      reason -> inspect(reason)
    end

    "Your query is incorrect\n\n#{error_detail}"
  end
end

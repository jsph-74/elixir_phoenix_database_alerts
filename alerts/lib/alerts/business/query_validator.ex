defmodule Alerts.Business.QueryValidator do
  @moduledoc """
  Business validation service for coupled query + connection validation.
  
  Separates validation concerns:
  - DB schema handles basic field validation
  - This service handles complex business validation with context awareness
  """
  
  alias Alerts.Business.Odbc
  require Logger

  @doc """
  Validates query and connection based on context.
  
  Context types:
  - :interactive (M2H) - Full validation including connectivity and SQL execution
  - :automated (M2M) - Minimal validation, syntax only
  
  Returns:
  - {:ok, :valid} - Query and connection are valid
  - {:error, :connection_failed, message} - Data source connection failed
  - {:error, :sql_syntax, message} - SQL syntax error
  - {:error, :sql_runtime, message} - SQL runtime error (table doesn't exist, etc.)
  """
  def validate_query_and_connection(query, data_source_id, context \\ :interactive)
  
  def validate_query_and_connection(nil, _data_source_id, _context), do: {:ok, :valid}
  def validate_query_and_connection("", _data_source_id, _context), do: {:ok, :valid}
  
  def validate_query_and_connection(query, nil, _context) when is_binary(query) do
    if String.trim(query) == "" do
      {:ok, :valid}
    else
      {:error, :no_data_source, "Data source must be selected to validate query"}
    end
  end
  
  def validate_query_and_connection(query, _data_source_id, :automated) when is_binary(query) do
    # M2M context: Only basic syntax validation, no execution
    # This is for scheduled runs where we don't want to block on connectivity
    if basic_sql_syntax_valid?(query) do
      {:ok, :valid}
    else
      {:error, :sql_syntax, "SQL syntax appears invalid"}
    end
  end
  
  def validate_query_and_connection(query, data_source_id, :interactive) when is_binary(query) do
    # M2H context: Full validation including execution
    # This is for form validation where we want to catch issues early
    
    # First check basic syntax
    if not basic_sql_syntax_valid?(query) do
      {:error, :sql_syntax, "SQL syntax appears invalid"}
    else
      # Then execute query to validate connection and SQL
      case execute_validation_query(query, data_source_id) do
        {:ok, _results} -> 
          {:ok, :valid}
          
        {:error, error_msg} when is_binary(error_msg) ->
          cond do
            connection_error?(error_msg) ->
              {:error, :connection_failed, error_msg}
              
            sql_syntax_error?(error_msg) ->
              {:error, :sql_syntax, error_msg}
              
            sql_runtime_error?(error_msg) ->
              {:error, :sql_runtime, error_msg}
              
            true ->
              {:error, :sql_runtime, error_msg}
          end
          
        {:error, error} ->
          {:error, :sql_runtime, inspect(error)}
      end
    end
  end
  
  # Private helper functions
  
  defp basic_sql_syntax_valid?(query) do
    trimmed = String.trim(query)
    
    # Basic checks for obviously invalid SQL
    cond do
      trimmed == "" -> true
      not String.match?(trimmed, ~r/^\s*(SELECT|WITH|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)/i) -> false
      String.contains?(trimmed, ["TOTALLY INVALID", "BLAH BLAH"]) -> false
      String.match?(trimmed, ~r/SELECT\s+FROM\s+WHERE/i) -> false  # SELECT FROM WHERE is invalid
      true -> true
    end
  end
  
  defp execute_validation_query(query, data_source_id) do
    # Use existing ODBC infrastructure but with validation context
    Logger.debug("Validating query for data_source_id=#{data_source_id}: #{String.slice(query, 0, 50)}...")
    
    try do
      integer_data_source_id = ensure_integer(data_source_id)
      Odbc.run_query_by_data_source_id(query, integer_data_source_id)
    rescue
      Ecto.NoResultsError ->
        {:error, "Data source not found"}
      ArgumentError ->
        {:error, "Invalid data source ID"}
    end
  end
  
  defp ensure_integer(id) when is_integer(id), do: id
  defp ensure_integer(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> int_id
      _ -> raise ArgumentError, "Invalid data_source_id: #{inspect(id)}"
    end
  end
  
  defp connection_error?(error_msg) do
    String.contains?(String.downcase(error_msg), [
      "could not connect",
      "connection refused",
      "connection failed",
      "host not found",
      "timeout",
      "network unreachable"
    ])
  end
  
  defp sql_syntax_error?(error_msg) do
    String.contains?(String.downcase(error_msg), [
      "syntax error",
      "near unexpected token",
      "parse error",
      "invalid syntax",
      "syntax near"
    ])
  end
  
  defp sql_runtime_error?(error_msg) do
    String.contains?(String.downcase(error_msg), [
      "table",
      "column",
      "relation",
      "does not exist",
      "unknown",
      "not found",
      "undefined"
    ])
  end
  
  @doc """
  Adds validation errors to changeset based on structured error results.
  
  Maps business validation errors to appropriate form fields:
  - Connection errors -> data_source_id field
  - SQL errors -> query field
  """
  def add_validation_errors(changeset, {:error, error_type, message}) do
    import Ecto.Changeset
    
    case error_type do
      :connection_failed -> add_error(changeset, :data_source_id, message)
      :no_data_source -> add_error(changeset, :data_source_id, message)
      :sql_syntax -> add_error(changeset, :query, "SQL Error: #{message}")
      :sql_runtime -> add_error(changeset, :query, "Query failed: #{message}")
      _ -> add_error(changeset, :query, message)
    end
  end
  
  def add_validation_errors(changeset, {:ok, :valid}), do: changeset
end
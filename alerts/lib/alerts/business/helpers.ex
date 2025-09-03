defmodule Alerts.Business.Helpers do
  @moduledoc """
  General utility functions that can be used across the application.
  """

  @doc """
  Normalizes values for comparison, handling different types consistently.
  """
  def normalize_value_for_comparison(value) when is_binary(value) do
    trimmed = value |> String.trim() |> String.trim("\n") |> String.trim()
    case trimmed do
      "" -> nil  # Treat empty/whitespace-only strings as nil
      _ ->
        # Convert numeric strings to numbers for proper comparison
        case Integer.parse(trimmed) do
          {int, ""} -> int
          _ -> trimmed
        end
    end
  end
  def normalize_value_for_comparison(value) when is_integer(value) do
    value
  end
  def normalize_value_for_comparison(value) when is_nil(value) do
    nil
  end
  def normalize_value_for_comparison(value) do
    to_string(value) |> normalize_value_for_comparison()
  end

  @doc """
  Gets parameter value from params map, handling both string and atom keys.
  """
  def get_param_value(params, field) when is_atom(field) do
    Map.get(params, field) || Map.get(params, to_string(field))
  end

  @doc """
  Trims query parameters in a params map.
  """
  def trim_query_params(params) when is_map(params) do
    params
    |> Map.update("query", nil, &trim_query/1)
    |> Map.update(:query, nil, &trim_query/1)
  end
  
  @doc """
  Trims whitespace and newlines from query strings.
  """
  def trim_query(nil), do: nil
  def trim_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> String.trim("\n")
    |> String.trim()
  end
  def trim_query(query), do: query

  @doc """
  Checks if there are meaningful changes between a struct and new params.
  """
  def has_meaningful_changes?(struct, params, meaningful_fields) do
    Enum.any?(meaningful_fields, fn field ->
      current_value = Map.get(struct, field)
      new_value = get_param_value(params, field)
      
      # Normalize values for comparison (handle both string and atom keys)
      normalized_current = normalize_value_for_comparison(current_value)
      normalized_new = normalize_value_for_comparison(new_value)
      
      normalized_current != normalized_new
    end)
  end
end
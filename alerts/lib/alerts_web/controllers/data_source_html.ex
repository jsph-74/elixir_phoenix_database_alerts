defmodule AlertsWeb.DataSourceHTML do
  @moduledoc """
  This module contains templates rendered by DataSourceController.
  """
  use AlertsWeb, :html

  embed_templates "data_source_html/*"

  def render_usage_count(data_source_name, usage_stats) do
    case Map.get(usage_stats, data_source_name, 0) do
      0 -> content_tag(:span, "No alerts", class: "text-muted")
      1 -> content_tag(:span, "1 alert", class: "text-info")
      count -> content_tag(:span, "#{count} alerts", class: "text-warning")
    end
  end


  def can_delete?(data_source_name, usage_stats) do
    Map.get(usage_stats, data_source_name, 0) == 0
  end

  def connection_test_button_class(can_delete) do
    if can_delete, do: "btn btn-info btn-sm", else: "btn btn-info btn-sm"
  end

  def delete_button_class(can_delete) do
    if can_delete, do: "btn btn-danger btn-sm", else: "btn btn-danger btn-sm disabled"
  end

  def format_additional_params(params) when is_map(params) and map_size(params) == 0 do
    content_tag(:em, "None")
  end

  def format_additional_params(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(", ")
    |> Phoenix.HTML.raw()
  end

  def format_additional_params(params) when is_binary(params) do
    case Jason.decode(params) do
      {:ok, decoded} when is_map(decoded) and map_size(decoded) > 0 ->
        format_additional_params(decoded)
      {:ok, decoded} when is_map(decoded) ->
        content_tag(:em, "None")
      {:error, _} ->
        Phoenix.HTML.raw(Phoenix.HTML.html_escape(params))
    end
  end

  def format_additional_params(_), do: content_tag(:em, "None")

  def mask_password(nil), do: ""
  def mask_password(""), do: ""
  def mask_password(_), do: "••••••••"
  
  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error), class: "help-block", style: "color: #d9534f; font-weight: normal;")
    end)
  end

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(AlertsWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AlertsWeb.Gettext, "errors", msg, opts)
    end
  end

  def render_view_icon() do
    raw("""
    <svg class='bi bi-eye' width='1em' height='1em' viewBox='0 0 16 16' fill='currentColor' xmlns='http://www.w3.org/2000/svg'>
      <path d='M16 8s-3-5.5-8-5.5S0 8 0 8s3 5.5 8 5.5S16 8 16 8zM1.173 8a13.133 13.133 0 0 1 1.66-2.043C4.12 4.668 5.88 3.5 8 3.5c2.12 0 3.879 1.168 5.168 2.457A13.133 13.133 0 0 1 14.828 8c-.058.087-.122.183-.195.288-.335.48-.83 1.12-1.465 1.755C11.879 11.332 10.119 12.5 8 12.5c-2.12 0-3.879-1.168-5.168-2.457A13.134 13.134 0 0 1 1.172 8z'/>
      <path d='M8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM4.5 8a3.5 3.5 0 1 1 7 0 3.5 3.5 0 0 1-7 0z'/>
    </svg>
    """)
  end

  def render_edit_icon() do
    raw("""
    <svg width="14" height="14" fill="currentColor" viewBox="0 0 16 16" style="vertical-align: middle;">
      <path d="M12.146.146a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1 0 .708l-10 10a.5.5 0 0 1-.168.11l-5 2a.5.5 0 0 1-.65-.65l2-5a.5.5 0 0 1 .11-.168zM11.207 2.5 13.5 4.793 14.793 3.5 12.5 1.207zm1.586 3L10.5 3.207 4 9.707V10h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.293zm-9.761 5.175-.106.106-1.528 3.821 3.821-1.528.106-.106A.5.5 0 0 1 5 12.5V12h-.5a.5.5 0 0 1-.5-.5V11h-.5a.5.5 0 0 1-.468-.325"/>
    </svg>
    """)
  end

  def render_test_icon() do
    raw("""
    <svg class='bi bi-link-45deg' width='1.2em' height='1.2em' viewBox='0 0 16 16' fill='currentColor' style='vertical-align: middle;'>
      <path d='M4.715 6.542 3.343 7.914a3 3 0 1 0 4.243 4.243l1.828-1.829A3 3 0 0 0 8.586 5.5L8 6.086a1.002 1.002 0 0 0-.154.199 2 2 0 0 1 .861 3.337L6.88 11.45a2 2 0 1 1-2.83-2.83l.793-.792a4.018 4.018 0 0 1-.128-1.287z'/>
      <path d='M6.586 4.672A3 3 0 0 0 7.414 9.5l.775-.776a2 2 0 0 1-.896-3.346L9.12 3.55a2 2 0 1 1 2.83 2.83l-.793.792c.112.42.155.855.128 1.287l1.372-1.372a3 3 0 1 0-4.243-4.243L6.586 4.672z'/>
    </svg>
    """)
  end

  def render_delete_icon() do
    raw("""
    <svg class='bi bi-trash-fill' width='1.2em' height='1.2em' viewBox='0 0 16 16' fill='#dc3545' style='vertical-align: middle;'>
      <path d='M2.5 1a1 1 0 0 0-1 1v1a1 1 0 0 0 1 1H3v9a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V4h.5a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1H10a1 1 0 0 0-1-1H7a1 1 0 0 0-1 1H2.5zm3 4a.5.5 0 0 1 .5.5v7a.5.5 0 0 1-1 0v-7a.5.5 0 0 1 .5-.5zM8 5a.5.5 0 0 1 .5.5v7a.5.5 0 0 1-1 0v-7A.5.5 0 0 1 8 5zm3 .5v7a.5.5 0 0 1-1 0v-7a.5.5 0 0 1 1 0z'/>
    </svg>
    """)
  end
end
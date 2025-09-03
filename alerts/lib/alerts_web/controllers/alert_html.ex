defmodule AlertsWeb.AlertHTML do
  @moduledoc """
  This module contains templates rendered by AlertController.
  """
  use AlertsWeb, :html

  require AlertsWeb.Helpers
  alias Alerts.Business.DB

  @alert_hours 4

  embed_templates "alert_html/*"

  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error), class: "help-block", style: "color: #d9534f; font-weight: normal;")
    end)
  end

  def form_validation_error_tag(form, field) do
    # Only show basic validation errors, filter out SQL database errors
    form_errors = AlertsWeb.Helpers.get_form_validation_errors(form, field)
    Enum.map(form_errors, fn error ->
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

  def render_date(date) do
    case date do
      nil -> content_tag(:em, "never")
      "" -> content_tag(:em, "never")
      _ -> date |> AlertsWeb.Helpers.format_date_relative_and_local()
    end
  end

  def render_date_relative(date) do
    case date do
      nil -> content_tag(:em, "never")
      "" -> content_tag(:em, "never")
      _ -> date |> AlertsWeb.Helpers.format_date_relative()
    end
  end

  def active_tab_class(current, active) do
    if current == active do
      "active"
    else
      ""
    end
  end

  def render_total(total) do
    case total do
      nil -> "-"
      _ -> total
    end
  end

  def render_source(nil), do: content_tag(:em, "No data source", class: "text-muted")
  def render_source(%DB.DataSource{} = data_source), do: data_source.display_name || data_source.name
  def render_source(source) when is_binary(source), do: source  # For backward compatibility

  def render_status(%DB.Alert{status: "broken", last_run: date}) do
    content_tag(:span, "broken#{old(date)}", class: "label label-default", style: "background-color: black; color: white;")
  end

  def render_status(%DB.Alert{status: "bad", last_run: date}) do
    content_tag(:span, "bad#{old(date)}", class: "label label-danger")
  end

  def render_status(%DB.Alert{status: "never run", last_run: date}) do
    content_tag(:span, "never run#{old(date)}", class: "label label-info")
  end

  def render_status(%DB.Alert{status: "needs refreshing", last_run: date}) do
    content_tag(:span, "needs refreshing#{old(date)}", class: "label label-info")
  end

  def render_status(%DB.Alert{status: "good", last_run: date}) do
    content_tag(:span, "good#{old(date)}", class: "label label-success")
  end

  def render_status(%DB.Alert{status: "under_threshold", last_run: date}) do
    content_tag(:span, "under threshold#{old(date)}",
      class: "label label-warning"
    )
  end

  def render_status(%DB.Alert{status: unknown, last_run: date}) do
    content_tag(:span, "#{unknown}#{old(date)}", class: "label label-danger")
  end

  def old(nil), do: ""

  def old(date) do
    case Timex.diff(Timex.now(), date, :hours) > @alert_hours do
      true -> " (*)"
      false -> ""
    end
  end

  def render_schedule(%DB.Alert{schedule: nil}), do: "manual"

  def render_schedule(%DB.Alert{schedule: schedule}),
    do:
      link(
        schedule,
        to: "https://crontab.guru/#" <> String.replace(schedule, " ", "_"),
        target: "_blank"
      )

  def render_history(%DB.Alert{} = _a) do
    # Legacy function - history is now handled in query history tab
    raw("""
      <svg class='bi bi-clock-history' width='1em' height='1em' viewBox='0 0 16 16' fill='currentColor' xmlns='http://www.w3.org/2000/svg'>
      <path fill-rule='evenodd' d='M8.515 1.019A7 7 0 008 1V0a8 8 0 01.589.022l-.074.997zm2.004.45a7.003 7.003 0 00-.985-.299l.219-.976c.383.086.76.2 1.126.342l-.36.933zm1.37.71a7.01 7.01 0 00-.439-.27l.493-.87a8.025 8.025 0 01.979.654l-.615.789a6.996 6.996 0 00-.418-.302zm1.834 1.79a6.99 6.99 0 00-.653-.796l.724-.69c.27.285.52.59.747.91l-.818.576zm.744 1.352a7.08 7.08 0 00-.214-.468l.893-.45a7.976 7.976 0 01.45 1.088l-.95.313a7.023 7.023 0 00-.179-.483zm.53 2.507a6.991 6.991 0 00-.1-1.025l.985-.17c.067.386.106.778.116 1.17l-1 .025zm-.131 1.538c.033-.17.06-.339.081-.51l.993.123a7.957 7.957 0 01-.23 1.155l-.964-.267c.046-.165.086-.332.12-.501zm-.952 2.379c.184-.29.346-.594.486-.908l.914.405c-.16.36-.345.706-.555 1.038l-.845-.535zm-.964 1.205c.122-.122.239-.248.35-.378l.758.653a8.073 8.073 0 01-.401.432l-.707-.707z' clip-rule='evenodd'/>
      <path fill-rule='evenodd' d='M8 1a7 7 0 104.95 11.95l.707.707A8.001 8.001 0 118 0v1z' clip-rule='evenodd'/>
      <path fill-rule='evenodd' d='M7.5 3a.5.5 0 01.5.5v5.21l3.248 1.856a.5.5 0 01-.496.868l-3.5-2A.5.5 0 017 9V3.5a.5.5 0 01.5-.5z' clip-rule='evenodd'/>
      </svg>
    """)
  end

  def render_download_icon() do
    raw("""
    <svg width="14" height="14" fill="currentColor" viewBox="0 0 16 16" style="vertical-align: middle;">
      <path d="M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5"/>
      <path d="M7.646 11.854a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293V1.5a.5.5 0 0 0-1 0v8.793L5.354 8.146a.5.5 0 1 0-.708.708z"/>
    </svg>
    """)
  end

  def truncate_id(id) when is_binary(id) do
    case String.split(id, "-", parts: 3) do
      [first_part, second_part, _rest] -> first_part <> "-" <> second_part <> "..."
      [first_part, second_part] -> first_part <> "-" <> second_part
      [single_part] -> single_part
    end
  end
  def truncate_id(id), do: to_string(id)

  def has_actual_diff?(previous, current) do
    get_diff_changes(previous, current) != []
  end

  def render_cute_diff(previous, current) do
    changes = get_diff_changes(previous, current)
    render_diff_items(changes)
  end
  
  defp get_diff_changes(previous, current) do
    changes = []
    
    changes = if String.trim(previous.name || "") != String.trim(current.name || "") do
      changes ++ [%{field: "Name", old: previous.name, new: current.name, emoji: "📝"}]
    else
      changes
    end
    
    changes = if String.trim(previous.description || "") != String.trim(current.description || "") do
      changes ++ [%{field: "Description", old: previous.description, new: current.description, emoji: "📄"}]
    else
      changes
    end
    
    changes = if String.trim(previous.query || "") != String.trim(current.query || "") do
      changes ++ [%{field: "SQL Query", old: previous.query, new: current.query, emoji: "🔍"}]
    else
      changes
    end
    
    changes = if previous.threshold != current.threshold do
      changes ++ [%{field: "Threshold", old: previous.threshold, new: current.threshold, emoji: "📊"}]
    else
      changes
    end
    
    changes = if previous.schedule != current.schedule do
      changes ++ [%{field: "Schedule", old: previous.schedule, new: current.schedule, emoji: "⏰"}]
    else
      changes
    end
    
    changes = if previous.data_source_id != current.data_source_id do
      changes ++ [%{field: "Data Source", old: previous.data_source_id, new: current.data_source_id, emoji: "🗃️"}]
    else
      changes
    end
    
    changes
  end
  
  def render_result_diff(previous, current) do
    changes = []
    
    changes = if previous.status != current.status do
      changes ++ [%{field: "Status", old: previous.status, new: current.status, emoji: "📊"}]
    else
      changes
    end
    
    changes = if previous.total_rows != current.total_rows do
      changes ++ [%{field: "Row Count", old: to_string(previous.total_rows), new: to_string(current.total_rows), emoji: "🔢"}]
    else
      changes
    end
    
    changes = if previous.error_message != current.error_message do
      old_error = if previous.error_message, do: previous.error_message, else: "No error"
      new_error = if current.error_message, do: current.error_message, else: "No error"
      changes ++ [%{field: "Error", old: old_error, new: new_error, emoji: "⚠️"}]
    else
      changes
    end
    
    # Show CSV data diff for small result sets (< 200 characters each)
    changes = if previous.result_hash != current.result_hash && 
                 String.length(previous.csv_data || "") < 200 &&
                 String.length(current.csv_data || "") < 200 do
      changes ++ [%{field: "Data", old: previous.csv_data || "", new: current.csv_data || "", emoji: "📋"}]
    else
      changes
    end
    
    render_diff_items(changes)
  end
  
  def render_diff_items(changes) do
    items = Enum.map(changes, fn change ->
      """
      <div class="diff-item">
        <div class="diff-field">
          <span class="diff-field-emoji">#{change.emoji}</span>
          <span class="diff-field-name">#{change.field}</span>
        </div>
        <div class="diff-values">
          <div class="diff-old">
            <span class="diff-label">Before:</span>
            <div class="diff-content old">#{format_diff_value(change.old)}</div>
          </div>
          <div class="diff-new">
            <span class="diff-label">After:</span>
            <div class="diff-content new">#{format_diff_value(change.new)}</div>
          </div>
        </div>
      </div>
      """
    end)
    
    raw(Enum.join(items, ""))
  end
  
  defp format_diff_value(value) when is_nil(value), do: "<em class=\"text-muted\">empty</em>"
  defp format_diff_value(value) when is_binary(value) and byte_size(value) == 0, do: "<em class=\"text-muted\">empty</em>"
  defp format_diff_value(value) when is_binary(value) do
    trimmed = String.trim(value)
    
    cond do
      # For SQL queries (contains SELECT, FROM, etc.), preserve structure exactly
      String.contains?(String.upcase(trimmed), ["SELECT", "FROM", "WHERE", "UPDATE", "INSERT"]) ->
        escaped_content = Phoenix.HTML.html_escape(trimmed) |> Phoenix.HTML.safe_to_string()
        "<pre style=\"margin: 0; padding: 0; border: none; white-space: pre-wrap; font-family: monospace; font-size: 12px; background: inherit; color: inherit;\">#{escaped_content}</pre>"
        
      # For data with newlines (CSV data, multi-line content), preserve structure exactly
      String.contains?(trimmed, "\n") ->
        escaped_content = Phoenix.HTML.html_escape(trimmed) |> Phoenix.HTML.safe_to_string()
        "<pre style=\"margin: 0; padding: 0; border: none; white-space: pre-wrap; font-family: monospace; font-size: 12px; background: inherit; color: inherit;\">#{escaped_content}</pre>"
        
      # For simple strings, just trim and handle basic formatting
      true ->
        trimmed
        |> String.replace(~r/\s+/, " ")  # Normalize whitespace
        |> String.replace(~r/ /, "&nbsp;")  # Preserve spaces
    end
  end
  defp format_diff_value(value), do: to_string(value)

  def render_play_icon() do
    raw("""
    <svg width="14" height="14" fill="currentColor" viewBox="0 0 16 16" style="vertical-align: middle;">
      <path d="m11.596 8.697-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 0 1 0 1.393"/>
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

  def render_delete_icon() do
    raw("""
    <svg width="14" height="14" fill="currentColor" viewBox="0 0 16 16" style="vertical-align: middle;">
      <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5m2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5m3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0z"/>
      <path d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4zM2.5 3h11V2h-11z"/>
    </svg>
    """)
  end

  def render_view_icon() do
    raw("""
    <svg width="14" height="14" fill="currentColor" viewBox="0 0 16 16" style="vertical-align: middle;">
      <path d="M16 8s-3-5.5-8-5.5S0 8 0 8s3 5.5 8 5.5S16 8 16 8zM1.173 8a13.133 13.133 0 0 1 1.66-2.043C4.12 4.668 5.88 3.5 8 3.5c2.12 0 3.879 1.168 5.168 2.457A13.133 13.133 0 0 1 14.828 8c-.058.087-.122.183-.195.288-.335.48-.83 1.12-1.465 1.755C11.879 11.332 10.119 12.5 8 12.5c-2.12 0-3.879-1.168-5.168-2.457A13.134 13.134 0 0 1 1.172 8z"/>
      <path d="M8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM4.5 8a3.5 3.5 0 1 1 7 0 3.5 3.5 0 0 1-7 0z"/>
    </svg>
    """)
  end

  def render_inline_diff(old_query, new_query) do
    old_lines = String.split(old_query || "", "\n")
    new_lines = String.split(new_query || "", "\n")
    
    changes = detect_diff_changes(old_lines, new_lines)
    
    content_tag(:div, class: "diff-lines") do
      Enum.map(changes, fn
        {:unchanged, line, _} ->
          content_tag(:div, class: "diff-line unchanged") do
            [
              content_tag(:span, " ", class: "diff-marker"),
              content_tag(:code, line, class: "diff-code")
            ]
          end
        
        {:removed, line, _} ->
          content_tag(:div, class: "diff-line removed") do
            [
              content_tag(:span, "-", class: "diff-marker"),
              content_tag(:code, line, class: "diff-code")
            ]
          end
        
        {:added, line, _} ->
          content_tag(:div, class: "diff-line added") do
            [
              content_tag(:span, "+", class: "diff-marker"),
              content_tag(:code, line, class: "diff-code")
            ]
          end
      end)
    end
  end

  defp detect_diff_changes(old_lines, new_lines) do
    max_length = max(length(old_lines), length(new_lines))
    
    0..(max_length - 1)
    |> Enum.map(fn i ->
      old_line = Enum.at(old_lines, i)
      new_line = Enum.at(new_lines, i)
      
      cond do
        old_line == nil -> {:added, new_line, i}
        new_line == nil -> {:removed, old_line, i}
        old_line != new_line -> 
          # For simplicity, show both removed and added lines
          [{:removed, old_line, i}, {:added, new_line, i}]
        true -> {:unchanged, old_line, i}
      end
    end)
    |> List.flatten()
  end

  @doc """
  Renders a diff between two alert versions showing what changed.
  """
  def render_alert_version_diff(old_alert, new_alert) do
    changes = detect_alert_changes(old_alert, new_alert)
    
    if Enum.any?(changes) do
      content_tag(:div, class: "alert-diff") do
        Enum.map(changes, fn {field, old_value, new_value} ->
          render_version_field_change(field, old_value, new_value)
        end)
      end
    else
      content_tag(:div, class: "alert alert-info") do
        "No changes detected"
      end
    end
  end

  @doc """
  Renders the initial alert version (for creation).
  """
  def render_initial_alert_version(alert) do
    content_tag(:div, class: "alert-snapshot") do
      [
        content_tag(:h5, "Initial Alert Configuration"),
        content_tag(:div, class: "snapshot-fields") do
          relevant_fields(alert)
          |> Enum.map(fn {field, value} ->
            content_tag(:div, class: "field-item") do
              [
                content_tag(:strong, humanize_field_name(field)),
                ": ",
                render_field_value(field, value)
              ]
            end
          end)
        end
      ]
    end
  end

  defp detect_alert_changes(old_alert, new_alert) do
    fields_to_compare = [:name, :description, :context, :query, :threshold, :schedule]
    
    Enum.reduce(fields_to_compare, [], fn field, acc ->
      old_value = Map.get(old_alert, field)
      new_value = Map.get(new_alert, field)
      
      if old_value != new_value do
        [{field, old_value, new_value} | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  defp relevant_fields(alert) do
    [
      {:name, alert.name},
      {:description, alert.description},
      {:context, alert.context},
      {:query, alert.query},
      {:threshold, alert.threshold},
      {:schedule, alert.schedule}
    ]
    |> Enum.reject(fn {_field, value} -> is_nil(value) or value == "" end)
  end

  defp render_version_field_change(field, old_value, new_value) do
    [
      content_tag(:div, class: "diff-line removed") do
        [
          content_tag(:span, "-", class: "diff-marker"),
          content_tag(:strong, humanize_field_name(field)),
          ": ",
          render_field_value(field, old_value)
        ]
      end,
      content_tag(:div, class: "diff-line added") do
        [
          content_tag(:span, "+", class: "diff-marker"),
          content_tag(:strong, humanize_field_name(field)),
          ": ",
          render_field_value(field, new_value)
        ]
      end
    ]
  end


  defp humanize_field_name(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp render_field_value(:query, value) do
    content_tag(:pre, value || "", class: "diff-code")
  end

  defp render_field_value(:description, value) do
    content_tag(:pre, value || "", class: "diff-code")
  end

  defp render_field_value(_field, value) do
    content_tag(:span, to_string(value || ""), class: "diff-value")
  end

  @doc """
  Checks if there are changes in description or SQL between two alert versions.
  """
  def has_description_or_sql_changes?(old_alert, new_alert) do
    old_alert.description != new_alert.description || 
    old_alert.query != new_alert.query
  end

  @doc """
  Returns CSS class for field changes - highlights changed fields in green.
  """
  def get_field_change_class(field, current_history, history_list, current_index) do
    # Don't highlight the first (oldest) entry
    if current_index >= length(history_list) - 1 do
      ""
    else
      previous_history = Enum.at(history_list, current_index + 1)
      current_value = get_field_value(field, current_history)
      previous_value = get_field_value(field, previous_history)
      
      if current_value != previous_value do
        "field-changed"
      else
        ""
      end
    end
  end

  defp get_field_value("name", history), do: history.name
  defp get_field_value("context", history), do: history.context  
  defp get_field_value("data_source", history), do: if(history.data_source, do: history.data_source.name, else: nil)
  defp get_field_value("schedule", history), do: history.schedule
  defp get_field_value("threshold", history), do: history.threshold

  @doc """
  Renders diff only for description and SQL fields between two alert versions.
  """
  def render_description_and_sql_diff(old_alert, new_alert) do
    changes = []
    
    # Check description changes
    changes = if old_alert.description != new_alert.description do
      [{"Description", old_alert.description, new_alert.description} | changes]
    else
      changes
    end
    
    # Check SQL changes  
    changes = if old_alert.query != new_alert.query do
      [{"SQL", old_alert.query, new_alert.query} | changes]
    else
      changes
    end
    
    if Enum.any?(changes) do
      content_tag(:div, class: "focused-diff") do
        Enum.map(changes, fn {field_name, old_value, new_value} ->
          [
            content_tag(:h5, field_name, style: "margin-top: 20px; margin-bottom: 10px;"),
            content_tag(:div, class: "diff-line removed") do
              [
                content_tag(:span, "-", class: "diff-marker"),
                content_tag(:pre, old_value || "", class: "diff-code", style: "margin: 0;")
              ]
            end,
            content_tag(:div, class: "diff-line added") do
              [
                content_tag(:span, "+", class: "diff-marker"),
                content_tag(:pre, new_value || "", class: "diff-code", style: "margin: 0;")
              ]
            end
          ]
        end)
      end
    else
      content_tag(:div, class: "alert alert-info") do
        "No changes in description or SQL"
      end
    end
  end

  @doc """
  Renders the initial description and SQL (for creation).
  """
  def render_initial_description_and_sql(alert) do
    content_tag(:div, class: "initial-content") do
      [
        content_tag(:h5, "Description", style: "margin-top: 20px; margin-bottom: 10px;"),
        content_tag(:div, class: "diff-line added") do
          [
            content_tag(:span, "+", class: "diff-marker"),
            content_tag(:pre, alert.description || "", class: "diff-code", style: "margin: 0;")
          ]
        end,
        content_tag(:h5, "SQL", style: "margin-top: 20px; margin-bottom: 10px;"),
        content_tag(:div, class: "diff-line added") do
          [
            content_tag(:span, "+", class: "diff-marker"),
            content_tag(:pre, alert.query || "", class: "diff-code", style: "margin: 0;")
          ]
        end
      ]
    end
  end
end
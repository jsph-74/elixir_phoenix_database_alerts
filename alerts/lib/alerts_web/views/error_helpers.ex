defmodule AlertsWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use PhoenixHTMLHelpers

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      if field == :query && is_sql_error?(error) do
        format_sql_error_tag(error)
      else
        content_tag(:span, translate_error(error), class: "help-block", style: "color: #d9534f; font-weight: normal;")
      end
    end)
  end

  defp is_sql_error?({msg, _opts}) when is_binary(msg) do
    String.starts_with?(msg, "Your query is incorrect")
  end
  defp is_sql_error?(_), do: false

  defp format_sql_error_tag({msg, opts}) do
    case String.split(msg, "\n\n", parts: 2) do
      [header, technical_error] ->
        header_text = translate_error({header, opts})
        raw_html = """
        <div class="help-block" style="color: #d9534f; font-weight: normal;">
          <div>#{Phoenix.HTML.html_escape(header_text)}</div>
          <pre style="font-family: monospace; font-size: 12px; margin-top: 8px; white-space: pre-wrap; background-color: #f5f5f5; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">#{Phoenix.HTML.html_escape(technical_error)}</pre>
        </div>
        """
        Phoenix.HTML.raw(raw_html)
      [single_msg] ->
        content_tag(:span, translate_error({single_msg, opts}), class: "help-block", style: "color: #d9534f; font-weight: normal;")
    end
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext "errors", "is invalid"
    #
    #     # Translate the number of files with plural rules
    #     dngettext "errors", "1 file", "%{count} files", count
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(AlertsWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AlertsWeb.Gettext, "errors", msg, opts)
    end
  end
end

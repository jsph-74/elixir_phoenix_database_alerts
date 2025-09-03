defmodule AlertsWeb.AuthHTML do
  @moduledoc """
  This module contains pages rendered by AuthController.
  """

  use AlertsWeb, :html

  embed_templates "auth_html/*"
end
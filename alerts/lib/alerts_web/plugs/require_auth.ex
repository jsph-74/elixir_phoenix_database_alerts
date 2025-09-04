defmodule AlertsWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug to require master password authentication for protected routes.
  Redirects to login page if not authenticated or session expired.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]
  alias Alerts.Business.MasterPassword

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip authentication if master password is not configured
    if not MasterPassword.master_password_configured?() do
      assign(conn, :authenticated, false)
    else
      check_authentication(conn)
    end
  end

  defp check_authentication(conn) do
    case get_session(conn, :authenticated) do
      true ->
        # Check session timeout and set authenticated assign
        conn
        |> assign(:authenticated, true)
        |> check_session_timeout()
        
      _ ->
        # Not authenticated, redirect to login
        conn
        |> assign(:authenticated, false)
        |> redirect_to_login()
    end
  end

  defp check_session_timeout(conn) do
    last_activity = get_session(conn, :last_activity)
    timeout_minutes = get_session_timeout_minutes()
    current_time = System.system_time(:second)
    
    # If no last activity, set it now and continue
    if is_nil(last_activity) do
      put_session(conn, :last_activity, current_time)
    else
      # Check if session expired
      timeout_seconds = timeout_minutes * 60
      if (current_time - last_activity) > timeout_seconds do
        # Session expired - redirect to login
        conn
        |> clear_session()
        |> put_flash(:error, "Session expired. Please log in again.")
        |> redirect_to_login()
      else
        # Session valid - update activity and continue
        put_session(conn, :last_activity, current_time)
      end
    end
  end


  defp get_session_timeout_minutes do
    case System.get_env("SESSION_TIMEOUT_MINUTES") do
      nil -> 10  # Default 10 minutes
      timeout_str ->
        case Integer.parse(timeout_str) do
          {timeout, ""} when timeout > 0 -> timeout
          _ -> 10  # Fallback to default if parsing fails
        end
    end
  end

  defp redirect_to_login(conn) do
    conn
    |> halt()
    |> redirect(to: "/auth/login")
  end
end
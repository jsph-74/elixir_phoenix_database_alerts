defmodule AlertsWeb.AuthController do
  use AlertsWeb, :controller
  alias Alerts.Business.MasterPassword

  def login(conn, _params) do
    render(conn, :login)
  end

  def authenticate(conn, %{"master_password" => password}) do
    case MasterPassword.validate_master_password(password) do
      {:ok, :valid} ->
        conn
        |> put_session(:authenticated, true)
        |> put_session(:last_activity, System.system_time(:second))
        |> put_flash(:info, "Login successful!")
        |> redirect(to: ~p"/")
        
      {:error, :invalid} ->
        conn
        |> put_flash(:error, "Invalid master password. Please try again.")
        |> render(:login)
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> render(:login)
    end
  end

  def authenticate(conn, _params) do
    conn
    |> put_flash(:error, "Password is required.")
    |> render(:login)
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out successfully.")
    |> redirect(to: ~p"/auth/login")
  end
end
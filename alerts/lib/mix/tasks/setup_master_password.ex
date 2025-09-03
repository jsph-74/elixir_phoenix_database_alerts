defmodule Mix.Tasks.Alerts.SetupMasterPassword do
  @moduledoc """
  Set up master password for the Alerts application.

  ## Examples

      mix alerts.setup_master_password "my_secure_password"

  """
  use Mix.Task

  alias Alerts.Business.MasterPassword

  @shortdoc "Set up master password for application security"

  @impl Mix.Task
  def run([password]) when is_binary(password) do
    # Start the application
    Mix.Task.run("app.start")

    setup_password(password)
  end

  def run([]) do
    Mix.Task.run("app.start")
    
    IO.puts("❌ Usage: mix alerts.setup_master_password \"your_password\"")
    IO.puts("Example: mix alerts.setup_master_password \"my_secure_password123\"")
    System.halt(1)
  end

  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("❌ Usage: mix alerts.setup_master_password \"your_password\"")
    System.halt(1)
  end

  defp setup_password(password) do
    IO.puts("🔐 Setting up master password...")

    # Check password strength
    if String.length(password) < 8 do
      IO.puts("❌ Password must be at least 8 characters long.")
      System.halt(1)
    end

    # Check if master password already exists
    if MasterPassword.master_password_configured?() do
      IO.puts("⚠️  Master password is already configured. Updating...")
    end

    case MasterPassword.setup_master_password(password) do
      {:ok, _record} ->
        IO.puts("✅ Master password configured successfully!")
        IO.puts("The application will now require this password on startup.")
        
      {:error, changeset} ->
        IO.puts("❌ Failed to save master password:")
        IO.inspect(changeset.errors)
        System.halt(1)
    end
  end
end
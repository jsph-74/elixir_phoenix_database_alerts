defmodule Alerts.Business.DB.AppSecurity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "app_security" do
    field :key_type, :string
    field :encrypted_value, :binary
    field :created_at, :naive_datetime
    field :last_changed, :naive_datetime
  end

  @doc false
  def changeset(app_security, attrs) do
    app_security
    |> cast(attrs, [:key_type, :encrypted_value, :created_at, :last_changed])
    |> validate_required([:key_type, :encrypted_value, :created_at, :last_changed])
    |> unique_constraint(:key_type)
  end
end
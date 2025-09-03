#!/usr/bin/env bash
set -e

# Install/update dependencies first
mix local.hex --force
mix deps.get

# Wait for Postgres to become available
export PGPASSWORD=postgres
until psql -p 5432 -h alerts_db -U "postgres" -c '\q' 2>/dev/null; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

# Setup database
mix ecto.create -r Alerts.Repo
mix ecto.migrate -r Alerts.Repo


# Start Phoenix server
PORT=${PORT:-4000} mix phx.server

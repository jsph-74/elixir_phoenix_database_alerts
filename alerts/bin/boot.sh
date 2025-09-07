#!/usr/bin/env bash
set -e

# Install/update dependencies first
mix local.hex --force --unsafe-https
mix deps.get
mix deps.compile

# Wait for Postgres to become available
export PGPASSWORD=postgres
until psql -h ${DATABASE_HOST:-db-dev} -U postgres -c '\q' 2>/dev/null; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

# Auto-setup database (create only if doesn't exist, always migrate)
mix ecto.create --quiet || true
mix ecto.migrate


# Start Phoenix server
PORT=${PORT:-4000} mix phx.server

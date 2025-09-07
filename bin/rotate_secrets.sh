#!/bin/bash
set -e

# Rotate secrets - simple 4-step process
# Usage: ./bin/rotate_secrets.sh [environment]

ENV="${1:-dev}"

# Source shared functions
source "./bin/helpers/functions.sh"

echo "🔄 Rotating secrets for $ENV environment"

# Check if container is running
check_container_running "$ENV"

# Create new secrets
source ./bin/helpers/crypto/secrets.sh "$ENV"

# Rotate encrypted data in database (old key from mounted secret, new key as parameter)
if [ -n "$NEW_DB_ENCRYPTION_KEY" ]; then
    docker exec $(docker ps -q -f "name=alerts-${ENV}_web-${ENV}") mix run --no-halt scripts/rotate_encryption_key.exs "$NEW_DB_ENCRYPTION_KEY"
fi

# Generate compose file with new secret names and reboot
./bin/helpers/docker/create_docker_compose.sh "$ENV" "$NEW_DB_ENCRYPTION_SECRET_NAME" "$NEW_SECRET_SECRET_NAME"
./bin/startup.sh "$ENV" --reboot

echo "✅ Secret rotation complete!"
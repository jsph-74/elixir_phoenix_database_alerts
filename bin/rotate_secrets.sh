#!/bin/bash
set -e

# Rotate secrets - simple 4-step process
# Usage: ./bin/rotate_secrets.sh [environment]

ENV="${1:-dev}"

# Source shared functions
source "./bin/helpers/functions.sh"

echo "🔄 Rotating secrets for $ENV environment"

# Get old encryption key from running container
OLD_KEY=$(docker exec $(docker ps -q -f "name=alerts-${ENV}_web-${ENV}") cat /run/secrets/data_source_encryption_key 2>/dev/null || echo "")

# Create new secrets
source ./bin/helpers/crypto/secrets.sh "$ENV"

# Rotate encrypted data in database
if [ -n "$OLD_KEY" ] && [ -n "$NEW_DB_ENCRYPTION_KEY" ]; then
    docker exec $(docker ps -q -f "name=alerts-${ENV}_web-${ENV}") mix run --no-halt scripts/rotate_encryption_key.exs "$OLD_KEY" "$NEW_DB_ENCRYPTION_KEY"
fi

# Generate compose file and reboot
./bin/helpers/docker/create_docker_compose.sh "$ENV"
./bin/startup.sh "$ENV" --reboot

echo "✅ Secret rotation complete!"
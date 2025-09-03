#!/bin/bash
set -e

# Host wrapper script for SSL certificate generation
# This script calls the container-internal SSL generation script

# Source shared functions
source "$(dirname "$0")/../functions.sh"

ENVIRONMENT="${1:-dev}"
SERVICE_NAME=$(get_service_name "$ENVIRONMENT")

echo "🔐 Generating SSL certificate for $ENVIRONMENT environment..."

# Load environment variables for the service
if [ "$ENVIRONMENT" = "dev" ]; then
    export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-dev/encryption_key.txt)
elif [ "$ENVIRONMENT" = "test" ]; then
    export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-test/encryption_key.txt)
elif [ "$ENVIRONMENT" = "prod" ]; then
    export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-prod/encryption_key.txt)
    export SECRET_KEY_BASE=$(cat ~/.alerts-prod/secret_key_base.txt)
fi

# Get the correct service name for the environment
SERVICE_NAME=$(get_service_name "$ENVIRONMENT")

# Run the container-internal SSL generation script in the RUNNING container
docker-compose exec "$SERVICE_NAME" ./bin/generate_ssl_cert.sh "$ENVIRONMENT"

echo ""
echo "✅ SSL certificate generated in container!"
echo "🚀 Restart the $ENVIRONMENT service to apply SSL configuration:"
echo "   ./bin/$ENVIRONMENT/startup.sh"
#!/bin/bash
set -e

MIX_ENV="${1:-test}"
export MIX_ENV

echo "🧪 Running backend tests in $MIX_ENV environment..."

# Check if the stack is running
STACK_NAME="alerts-${MIX_ENV}"
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo "❌ Stack $STACK_NAME is not running. Please start it first"
    exit 1
fi

# Get the running web service container
WEB_CONTAINER=$(docker ps -q --filter "name=alerts-${MIX_ENV}_web")
if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not found. Is the stack running?"
    exit 1
fi

echo "✅ Using external test databases (mysql:3306, postgres:5433)"

# Run the tests
echo "🏃 Running Elixir/Phoenix tests..."
docker exec $WEB_CONTAINER bash -c 'export DATA_SOURCE_ENCRYPTION_KEY=$(cat /run/secrets/data_source_encryption_key) && mix test'

echo "✅ Backend tests completed!"

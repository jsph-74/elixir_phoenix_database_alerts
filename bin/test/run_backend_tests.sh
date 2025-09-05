#!/bin/bash
set -e

# Backend test runner
# Usage: ./bin/test/run_backend_tests.sh [test]
# Note: Only test environment supported due to SQL Sandbox requirements

# Parse parameters
MIX_ENV="${1:-test}"
export MIX_ENV

# Only allow test environment (tests require SQL Sandbox for proper isolation)
if [ "$MIX_ENV" != "test" ]; then
    echo "❌ Backend tests require 'test' environment, not '$MIX_ENV'"
    echo "💡 Tests use SQL Sandbox for proper test isolation"
    echo "💡 Usage: $0 [test]"
    exit 1
fi

echo "🧪 Running backend tests in $MIX_ENV environment..."

# Check if the stack is running
STACK_NAME="alerts-${MIX_ENV}"
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo "❌ Stack $STACK_NAME is not running. Please start it first with:"
    echo "  ./bin/startup.sh ${MIX_ENV}"
    exit 1
fi

# Get the running web service container
WEB_CONTAINER=$(docker ps -q --filter "name=alerts-${MIX_ENV}_web")
if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not found. Is the stack running?"
    exit 1
fi

# External test databases should be running already
echo "✅ Using external test databases (mysql:3306, postgres:5433)"

# Reset the test database to ensure clean state
echo "🔄 Resetting test database..."
./bin/helpers/db/reset.sh test

# Run the tests
echo "🏃 Running Elixir/Phoenix tests..."
docker exec $WEB_CONTAINER bash -c 'export DATA_SOURCE_ENCRYPTION_KEY=$(cat /run/secrets/data_source_encryption_key) && mix test'

echo "✅ Backend tests completed!"
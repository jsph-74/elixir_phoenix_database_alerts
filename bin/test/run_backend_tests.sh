#!/bin/bash
set -e

# Backend test runner
# Usage: ./bin/test/run_backend_tests.sh [dev|test]
# Run tests in dev to verify code doesn't break production-like environment
# Run tests in test for isolated testing with clean database

# Parse parameters
MIX_ENV="${1:-test}"
export MIX_ENV

# Only allow dev and test environments
if [ "$MIX_ENV" != "dev" ] && [ "$MIX_ENV" != "test" ]; then
    echo "❌ Backend tests can only run in 'dev' or 'test' environments, not '$MIX_ENV'"
    echo "💡 Usage: $0 [dev|test]"
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

# Tests use SQL Sandbox for isolation - no need to reset database

# Run the tests
echo "🏃 Running Elixir/Phoenix tests..."
docker exec $WEB_CONTAINER bash -c 'export DATA_SOURCE_ENCRYPTION_KEY=$(cat /run/secrets/data_source_encryption_key) && export MIX_TEST=1 && mix test'

echo "✅ Backend tests completed!"
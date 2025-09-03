#!/bin/bash
set -e

# Derive environment from MIX_ENV or parameter (default: test)
ENV_NAME="test"
KEY_FOLDER="alerts-${ENV_NAME}"

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

# Set trap for cleanup on error, Ctrl+C, or normal exit
trap docker_cleanup EXIT ERR INT TERM

echo y | source "$(dirname "$0")/../helpers/init_environment.sh" "$ENV_NAME"

# Get the correct service name for the environment
SERVICE_NAME=$(get_service_name "$ENV_NAME")
DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.${KEY_FOLDER}/encryption_key.txt)

# Run the Phoenix tests
print_status "🏃 Running backend tests (jobs/cron + meaningful integration tests)..." $YELLOW
MIX_ENV="$ENV_NAME" docker-compose run --rm -T --entrypoint="" -e DATA_SOURCE_ENCRYPTION_KEY="$DATA_SOURCE_ENCRYPTION_KEY" \
  $SERVICE_NAME mix test test/alerts/business/jobs_test.exs test/integration/data_source_test.exs test/integration/alert_lifecycle_test.exs

if [ $? -eq 0 ]; then
    print_status "✅ Backend tests passed!" $GREEN
else
    print_status "❌ Backend tests failed!" $RED
    exit 1
fi



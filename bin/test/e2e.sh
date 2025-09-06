#!/bin/bash
set -e

# E2E test runner
# Usage: ./bin/test/e2e.sh [dev|test] [OPTIONS] [grep_pattern]
# Run Playwright E2E tests against the specified environment
# OPTIONS: -w NUMBER (number of workers, default: 1)

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

# Parse parameters
MIX_ENV="${1:-test}"
WORKERS=1
GREP_PATTERN=""

# Parse options
shift  # Remove environment parameter
while getopts "w:" opt; do
  case $opt in
    w)
      WORKERS="$OPTARG"
      ;;
    \?)
      echo "Usage: $0 [dev|test] [-w workers] [grep_pattern]"
      echo "  -w: Number of Playwright workers (default: 1)"
      echo "  grep_pattern: Optional pattern to filter tests"
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))
GREP_PATTERN="$1"

export MIX_ENV

# Only allow dev and test environments
if [ "$MIX_ENV" != "dev" ] && [ "$MIX_ENV" != "test" ]; then
    print_status "❌ E2E tests can only run in 'dev' or 'test' environments, not '$MIX_ENV'" $RED
    exit 1
fi

print_status "🧪 Running E2E tests in $MIX_ENV environment (workers: $WORKERS)..." $BLUE


# Check if the stack is running
STACK_NAME="alerts-${MIX_ENV}"
if ! docker stack ls | grep -q "$STACK_NAME"; then
    print_status "❌ Stack $STACK_NAME is not running. Please start it first with:" $RED
    exit 1
fi

# External test databases should be running for E2E tests
print_status "✅ Using external test databases (mysql:3306, postgres:5433)" $GREEN

# Wait for the web application to be ready
BASE_URL=$(get_base_url "$MIX_ENV" "http")
print_status "⏳ Waiting for web application to be ready at $BASE_URL..." $YELLOW

retries=0
while [ $retries -lt 30 ]; do
    if curl -sf "$BASE_URL/data_sources" > /dev/null 2>&1; then
        break
    fi
    retries=$((retries + 1))
    echo -n "."
    sleep 2
done

if [ $retries -eq 30 ]; then
    echo ""
    print_status "❌ Web application failed to respond at $BASE_URL" $RED
    exit 1
fi

print_status "🎭 Running Playwright E2E tests in container..." $BLUE

# Get the playwright service container for the environment
PLAYWRIGHT_SERVICE="alerts-${MIX_ENV}_playwright"

# Start playwright service 
print_status "🚀 Starting Playwright service..." $YELLOW
docker service update --detach --replicas=1 "$PLAYWRIGHT_SERVICE"

# Wait for container to be ready
print_status "⏳ Waiting for Playwright container to start..." $YELLOW
retries=0
while [ $retries -lt 30 ]; do
    PLAYWRIGHT_CONTAINER=$(docker ps -q --filter "name=${PLAYWRIGHT_SERVICE}")
    if [ -n "$PLAYWRIGHT_CONTAINER" ]; then
        break
    fi
    retries=$((retries + 1))
    echo -n "."
    sleep 2
done

if [ -z "$PLAYWRIGHT_CONTAINER" ]; then
    echo ""
    print_status "❌ Playwright container failed to start after 60 seconds" $RED
    exit 1
fi

echo ""
print_status "✅ Playwright container ready" $GREEN

# Run tests inside the Playwright container
if [ -n "$GREP_PATTERN" ]; then
    docker exec "$PLAYWRIGHT_CONTAINER" ./node_modules/.bin/playwright test --grep "$GREP_PATTERN" --workers=$WORKERS --reporter=line
else
    docker exec "$PLAYWRIGHT_CONTAINER" ./node_modules/.bin/playwright test --workers=$WORKERS --reporter=line
fi

echo ""

if [ $? -eq 0 ]; then
    print_status "✅ E2E tests passed!" $GREEN
else
    print_status "❌ E2E tests failed!" $RED
    exit 1
fi
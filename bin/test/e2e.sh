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
    echo "💡 Usage: $0 [dev|test] [grep_pattern]"
    exit 1
fi

print_status "🧪 Running E2E tests in $MIX_ENV environment (workers: $WORKERS)..." $BLUE
if [ -n "$GREP_PATTERN" ]; then
    print_status "🔍 Filtering tests with pattern: '$GREP_PATTERN'" $YELLOW
fi

# Check if the stack is running
STACK_NAME="alerts-${MIX_ENV}"
if ! docker stack ls | grep -q "$STACK_NAME"; then
    print_status "❌ Stack $STACK_NAME is not running. Please start it first with:" $RED
    echo "  ./bin/startup.sh ${MIX_ENV}"
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

# Change to E2E test directory
cd e2e-tests

# @TODO:NOOOOOO THIS HAS TO BE RUN IN THE CONTAINERRRRRRRR, HOST == NO WARRANTY IS INSTALLED!!!!!!!!!!
print_status "🎭 Running Playwright E2E tests..." $BLUE
export PLAYWRIGHT_WORKERS=$WORKERS

if [ -n "$GREP_PATTERN" ]; then
    ./node_modules/.bin/playwright test --grep "$GREP_PATTERN" --workers=$WORKERS --reporter=line
else
    ./node_modules/.bin/playwright test --workers=$WORKERS --reporter=line
fi

echo ""

if [ $? -eq 0 ]; then
    print_status "✅ E2E tests passed!" $GREEN
else
    print_status "❌ E2E tests failed!" $RED
    exit 1
fi
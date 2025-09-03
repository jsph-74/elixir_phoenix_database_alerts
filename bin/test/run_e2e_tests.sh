#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

# Parse command line arguments
WORKERS=1
GREP_PATTERN=""

while getopts "w:" opt; do
  case $opt in
    w)
      WORKERS="$OPTARG"
      ;;
    \?)
      echo "Usage: $0 [-w workers] [grep_pattern]"
      echo "  -w: Number of Playwright workers (default: 1)"
      echo "  grep_pattern: Optional pattern to filter tests"
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))
GREP_PATTERN="$1"

# Derive environment from MIX_ENV or parameter (default: test)
ENV_NAME="test"
KEY_FOLDER="alerts-${ENV_NAME}"

if [ -n "$GREP_PATTERN" ]; then
  echo -e "\033[33m🧪 Running E2E Tests (grep: '$GREP_PATTERN', workers: $WORKERS)\033[0m"
else
  echo -e "\033[33m🧪 Running E2E Tests (Frontend Integration, workers: $WORKERS)\033[0m"
fi

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

# Set trap for cleanup on error, Ctrl+C, or normal exit
trap docker_cleanup EXIT ERR INT TERM

echo y | source "$(dirname "$0")/../helpers/init_environment.sh" "$ENV_NAME"
export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.${KEY_FOLDER}/encryption_key.txt)

print_status "Boot test web app" $YELLOW
MIX_ENV="$ENV_NAME" DATA_SOURCE_ENCRYPTION_KEY=$DATA_SOURCE_ENCRYPTION_KEY docker-compose up -d web-test
MIX_ENV="$ENV_NAME" DATA_SOURCE_ENCRYPTION_KEY=$DATA_SOURCE_ENCRYPTION_KEY docker-compose restart web-test 

retries=0
while [ $retries -lt 10 ]; do
    if curl -sf "$(get_base_url test)/data_sources" > /dev/null 2>&1; then
        break
    fi
    retries=$((retries + 1))
    echo -n "."
    sleep 2
done

if [ $retries -eq 10 ]; then
    print_status "❌ Web application failed to start" $RED
    exit 1
fi

# Run E2E tests (container builds automatically if needed)
print_status "Running E2E tests..." $YELLOW
echo "DEBUG: WORKERS=$WORKERS, PLAYWRIGHT_WORKERS will be set to $WORKERS"
if [ -n "$GREP_PATTERN" ]; then
  MIX_ENV="$ENV_NAME" DATA_SOURCE_ENCRYPTION_KEY=$DATA_SOURCE_ENCRYPTION_KEY PLAYWRIGHT_WORKERS=$WORKERS docker-compose --profile testing run --rm -e PLAYWRIGHT_WORKERS=$WORKERS playwright ./node_modules/.bin/playwright test --grep "$GREP_PATTERN" --reporter=line
else
  MIX_ENV="$ENV_NAME" DATA_SOURCE_ENCRYPTION_KEY=$DATA_SOURCE_ENCRYPTION_KEY PLAYWRIGHT_WORKERS=$WORKERS docker-compose --profile testing run --rm -e PLAYWRIGHT_WORKERS=$WORKERS playwright ./node_modules/.bin/playwright test --reporter=line
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ E2E tests passed!"
    echo ""
    echo "To browse the test app, run:"
    echo ""
    echo "       export DATA_SOURCE_ENCRYPTION_KEY=\$(cat ~/.${KEY_FOLDER}/encryption_key.txt) && MIX_ENV=$ENV_NAME docker-compose --profile testing up -d web-test"
    echo ""
    echo "Then access the app at: $(get_base_url test)"
else
    print_status "❌ E2E tests failed!" $RED
    exit 1
fi

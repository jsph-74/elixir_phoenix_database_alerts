#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

# Parse arguments
ENV="dev"
REBOOT=false

for arg in "$@"; do
    case $arg in
        --reboot|-r)
            REBOOT=true
            ;;
        dev|test|prod)
            ENV="$arg"
            ;;
    esac
done

# Get port for environment
PORT=$(get_http_port "$ENV")

# Remove existing stack if --reboot flag is used
STACK_NAME="alerts-$ENV"
if [ "$REBOOT" = true ] && docker stack ls --format "{{.Name}}" | grep -q "^$STACK_NAME$"; then
    echo "🔄 Rebooting $STACK_NAME..."
    docker stack rm $STACK_NAME
    echo "⏳ Waiting for network cleanup..."
    while docker network ls --format "{{.Name}}" | grep -q "${STACK_NAME}_default"; do
        sleep 2
    done
fi

echo "🚀 Starting $ENV environment with Docker Stack..."
docker stack deploy -c docker-compose-$ENV.yaml alerts-$ENV
echo "✅ $ENV available at http://localhost:$PORT"
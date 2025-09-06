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
echo
echo

# Remove existing stack if --reboot flag is used
STACK_NAME="alerts-$ENV"
if [ "$REBOOT" = true ] && docker stack ls --format "{{.Name}}" | grep -q "^$STACK_NAME$"; then
    echo "🔄 Rebooting $STACK_NAME..."
    docker stack rm $STACK_NAME
    while docker network ls --format "{{.Name}}" | grep -q "${STACK_NAME}_default"; do
        sleep 2
    done
fi

echo "🚀 Starting $ENV environment with Docker Stack..."
docker stack deploy -c docker-compose-$ENV.yaml alerts-$ENV

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."

for i in {1..30}; do
    if docker run --rm --network alerts-shared postgres:latest pg_isready -h db-$ENV -p 5432 -U postgres > /dev/null 2>&1; then
        echo "✅ Database is ready"
        break
    fi
    echo "Waiting for database... ($i/30)"
    sleep 2
done

# For dev/test, join Swarm services to the shared bridge network after deployment
if [ "$ENV" != "prod" ]; then
    ./bin/helpers/docker/join_sample_db_network.sh "$ENV"
fi

echo "✅ $ENV available at http://localhost:$PORT"
#!/bin/bash
set -e

# Parse arguments
PRUNE_DOCKER=false
ENV="dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prune)
            PRUNE_DOCKER=true
            shift
            ;;
        *)
            ENV="$1"
            shift
            ;;
    esac
done

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

print_status "🚀 FULL SETUP: Complete $ENV environment deployment" $BLUE
echo "=============================================================="
echo
echo "This will:"
if [ "$PRUNE_DOCKER" = true ]; then
    echo "- Clean all Docker resources"
fi
    echo "- Start external test databases (if not prod)"
    echo "- Initialize $ENV environment (secrets + compose + build)"
    echo "- Start $ENV environment"
    echo "- Seed database with sample data"

echo

confirm_or_exit "Proceed with full $ENV setup? (y/N): " "Setup cancelled."

# Step 1: Clean Docker (optional)
if [ "$PRUNE_DOCKER" = true ]; then
    echo y | ./bin/helpers/docker/prune.sh 
else
    # Even without prune, remove existing stack for this environment to avoid conflicts
    STACK_NAME="alerts-${ENV}"
    if docker stack ls --format "{{.Name}}" | grep -q "^${STACK_NAME}$"; then
        docker stack rm "$STACK_NAME"
        sleep 5
    fi
fi

# Step 2: Start external test databases (not for prod)
if [ "$ENV" != "prod" ]; then
    ./bin/helpers/db/start_sample_dbs.sh
fi

# Step 3: Initialize environment
./bin/init.sh "$ENV"
sleep 3

# Step 3.5: Create shared network and connect external databases
docker network create --driver overlay --attachable alerts-shared 2>/dev/null || echo "Network alerts-shared already exists"
if [ "$ENV" != "prod" ]; then
    docker network connect alerts-shared elixir_alerts-test-mysql-1 2>/dev/null || true
    docker network connect alerts-shared elixir_alerts-test-postgres-1 2>/dev/null || true
fi

# Step 4: Start environment
./bin/startup.sh "$ENV"

# Wait for application to be fully ready
print_status "Waiting for application to be ready..." $YELLOW
PORT=$(get_http_port "$ENV")
for i in {1..30}; do
    if curl -s -f http://localhost:$PORT > /dev/null 2>&1; then
        echo "Application is ready"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Step 5: Seed database
if [ "$ENV" != "prod" ]; then
    print_status "Seeding database with sample data..." $YELLOW
    ./bin/helpers/db/seed.sh "$ENV" --seed
fi

echo
print_status "🎉 FULL SETUP COMPLETE!" $GREEN
PORT=$(get_http_port "$ENV")
print_status "✅ $ENV environment is ready at: http://localhost:$PORT" $GREEN
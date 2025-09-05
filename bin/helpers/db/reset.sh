#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../functions.sh"

# Parse parameters
MIX_ENV="dev"
SEED_DB=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --seed)
            SEED_DB=true
            shift
            ;;
        *)
            MIX_ENV="$1"
            shift
            ;;
    esac
done

export MIX_ENV

# Check if the stack is running
STACK_NAME="alerts-${MIX_ENV}"
if ! docker stack ls | grep -q "$STACK_NAME"; then
    print_status "❌ Stack $STACK_NAME is not running. Please start it first with:" $RED
    echo "  ./bin/startup.sh ${MIX_ENV}"
    exit 1
fi

# Get the running web service container
WEB_CONTAINER=$(docker ps -q -f "name=${STACK_NAME}_web-${MIX_ENV}" | head -1)
if [ -z "$WEB_CONTAINER" ]; then
    print_status "❌ Web container not found. Is the stack running?" $RED
    exit 1
fi

if [ "$SEED_DB" = true ]; then
    # Start external test databases (needed for seeding)
    ./bin/helpers/db/start_external_testdbs.sh
    
    print_status "Seeding database..." $YELLOW
    docker exec $WEB_CONTAINER bash -c 'export DATA_SOURCE_ENCRYPTION_KEY=$(cat /run/secrets/data_source_encryption_key) && export DISABLE_SERVER=true && mix run -e "Application.ensure_all_started(:alerts); Code.eval_file(\"priv/repo/seeds.exs\")"'
    print_status "✅ Database seeded successfully!" $GREEN
fi

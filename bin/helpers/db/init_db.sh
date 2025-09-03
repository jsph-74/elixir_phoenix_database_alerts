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

# Derive key folder from MIX_ENV
KEY_FOLDER="alerts-${MIX_ENV}"

print_status "⚠ This will destroy ALL existing alerts data in [$MIX_ENV] database!" $YELLOW

confirm_or_exit "Do you want to proceed? (y/N): " "Database initialization cancelled."

# Create key if missing
./bin/helpers/crypto/init_encryption_key.sh > /dev/null 2>&1
export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.${KEY_FOLDER}/encryption_key.txt)

# Start the database container for the Phoenix application
print_status "Starting Phoenix database container..." $YELLOW
$(dirname "$0")/boot_db_containers.sh alerts_db

# For production, also export SECRET_KEY_BASE if available
ENV_VARS="-e MIX_ENV=$MIX_ENV -e DATA_SOURCE_ENCRYPTION_KEY=$DATA_SOURCE_ENCRYPTION_KEY"
if [ "$MIX_ENV" = "prod" ]; then
    export SECRET_KEY_BASE=$(cat ~/.alerts-prod/secret_key_base.txt)
    ENV_VARS="$ENV_VARS -e SECRET_KEY_BASE=$SECRET_KEY_BASE"
fi

# Get the correct service name for the environment
SERVICE_NAME=$(get_service_name "$MIX_ENV")

# Run database setup for the given environment with proper Ecto commands (bypass entrypoint)
print_status "Dropping database..." $YELLOW
docker-compose run --rm -T --entrypoint="" $ENV_VARS $SERVICE_NAME mix ecto.drop 

print_status "Creating database..." $YELLOW
docker-compose run --rm -T --entrypoint="" $ENV_VARS $SERVICE_NAME mix ecto.create 

print_status "Running migrations..." $YELLOW
docker-compose run --rm -T --entrypoint="" $ENV_VARS $SERVICE_NAME mix ecto.migrate > /dev/null 2>&1

if [ "$SEED_DB" = true ]; then
    # Start the monitored databases that alerts connect to (required for seeding sample data)
    print_status "Starting monitored databases (MySQL & PostgreSQL)..." $YELLOW
    $(dirname "$0")/boot_db_containers.sh external_data

    print_status "Seeding database..." $YELLOW
    docker-compose run --rm -T --entrypoint="" $ENV_VARS $SERVICE_NAME mix run priv/repo/seeds.exs > /dev/null 2>&1
fi

print_status "✅ Database initialized successfully!" $GREEN

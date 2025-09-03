#!/bin/bash
set -e

# Source shared functions
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR"/functions.sh"

# Environment parameter (one of: dev/test/prod)
MIX_ENV="${1:-dev}"
KEY_ENV="alerts-${MIX_ENV}"

echo "🛑 Stopping container $SERVICE_NAME"
SERVICE_NAME=$(get_service_name "$MIX_ENV")
docker-compose stop $SERVICE_NAME

# Reset database for specified environment
echo "🗄️ Setting up $MIX_ENV database..."

# For production, ensure secrets are initialized and load them
if [ "$MIX_ENV" = "prod" ]; then
    # Prod will not be sed
    SEED_FLAG=""
    # Initialize production secrets if needed
    $SCRIPT_DIR/../prod/init_prod_secrets.sh
    export SECRET_KEY_BASE=$(cat ~/.alerts-prod/secret_key_base.txt)
    export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-prod/encryption_key.txt)
else
    SEED_FLAG="--seed"
fi

if MIX_ENV="$MIX_ENV" $SCRIPT_DIR/../helpers/db/init_db.sh "$MIX_ENV" $SEED_FLAG; then
    echo ""
    echo "✅ Initialization complete, run the startup script in bin/$MIX_ENV/startup.sh"
fi

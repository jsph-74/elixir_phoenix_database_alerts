#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

# Read secrets from files
DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-prod/encryption_key.txt)
SECRET_KEY_BASE=$(cat ~/.alerts-prod/secret_key_base.txt)

# Export for docker-compose to use
export DATA_SOURCE_ENCRYPTION_KEY
export SECRET_KEY_BASE

./bin/helpers/db/boot_db_containers.sh alerts_db production
docker-compose --profile production up -d --force-recreate web-prod

echo "🌐 Production: $(get_base_url prod) (auto-redirects to HTTPS if SSL configured)"
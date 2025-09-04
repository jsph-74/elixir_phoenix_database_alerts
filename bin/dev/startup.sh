#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-dev/encryption_key.txt)
./bin/helpers/db/boot_db_containers.sh alerts_db
./bin/helpers/db/boot_db_containers.sh external_data
MIX_ENV=dev docker-compose up -d --force-recreate web-dev

echo "🔧 Development: $(get_base_url dev) (HTTPS available if SSL configured)"
#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-test/encryption_key.txt)
./bin/helpers/db/boot_db_containers.sh alerts_db testing
./bin/helpers/db/boot_db_containers.sh external_data testing
docker-compose --profile testing up -d --force-recreate web-test

echo "🧪 Test: $(get_base_url test) (HTTPS available if SSL configured)"
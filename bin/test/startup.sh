#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-test/encryption_key.txt)
docker-compose --profile testing up -d db test_mysql test_postgres
docker-compose --profile testing up -d --force-recreate web-test

echo "📄 HTTP: $(get_base_url test) | 🔒 HTTPS: $(get_base_url test https) (if SSL configured)"
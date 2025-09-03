#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

export DATA_SOURCE_ENCRYPTION_KEY=$(cat ~/.alerts-dev/encryption_key.txt)
MIX_ENV=dev docker-compose up -d db test_mysql test_postgres
MIX_ENV=dev docker-compose up -d --force-recreate web-dev

echo "📄 HTTP: $(get_base_url dev) | 🔒 HTTPS: $(get_base_url dev https) (if SSL configured)"
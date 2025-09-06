#!/bin/bash
set -e

# Derive environment from MIX_ENV or parameter (default: dev)
MIX_ENV="${MIX_ENV:-${1:-dev}}"
export MIX_ENV
KEY_FOLDER="alerts-${MIX_ENV}"

# Source shared functions
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"

echo "🔐 Creating Docker Swarm Secrets ($MIX_ENV -> $KEY_FOLDER)"
echo "==================================================="

# Check if Docker Swarm is initialized
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "^active$"; then
    docker swarm init --advertise-addr 127.0.0.1 >/dev/null 2>&1
fi

# Get existing secret names
EXISTING_ENCRYPTION_SECRET=$(./bin/helpers/crypto/get_secret_name.sh "$MIX_ENV" db_encryption_key)
if [ -n "$EXISTING_ENCRYPTION_SECRET" ]; then
    OLD_DB_ENCRYPTION_KEY=$(docker secret inspect $EXISTING_ENCRYPTION_SECRET --format '{{.Spec.Data}}' | base64 -d 2>/dev/null || echo "")
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Generate new encryption key
NEW_DB_ENCRYPTION_KEY=$(openssl rand -base64 32)
DB_ENCRYPTION_SECRET_NAME="data_source_encryption_key_${TIMESTAMP}"
echo "$NEW_DB_ENCRYPTION_KEY" | docker secret create "$DB_ENCRYPTION_SECRET_NAME" - >/dev/null

# Save new secret key base as Docker secret
SECRET_KEY_BASE=$(openssl rand -base64 64)
SECRET_SECRET_NAME="secret_key_base_${TIMESTAMP}"
echo "$SECRET_KEY_BASE" | docker secret create "$SECRET_SECRET_NAME" - >/dev/null

echo
echo -e "${GREEN}✅ Docker Swarm secrets created successfully!${NC}"
echo
echo -e "${BLUE}📋 Created secrets:${NC}"
echo "  • $DB_ENCRYPTION_SECRET_NAME"
echo "  • $SECRET_SECRET_NAME"

# Get existing master password secrer
MASTER_PASSWORD_SECRET_NAME=$(./bin/helpers/crypto/get_secret_name.sh "$MIX_ENV" master_password)
if [ -n "$MASTER_PASSWORD_SECRET_NAME" ]; then
    echo -e "${GREEN}✅ Found existing master password secret: $MASTER_PASSWORD_SECRET_NAME${NC}"
fi

# Export key for rotation scripts
export NEW_DB_ENCRYPTION_KEY

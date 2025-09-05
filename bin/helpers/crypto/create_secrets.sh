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
    echo -e "${YELLOW}⚠️  Docker Swarm is not initialized. Initializing now...${NC}"
    docker swarm init --advertise-addr 127.0.0.1 >/dev/null 2>&1
    echo -e "${GREEN}✅ Docker Swarm initialized${NC}"
else
    echo -e "${GREEN}✅ Docker Swarm already initialized${NC}"
fi

echo -e "${BLUE}📂 Working with Docker secrets only (no host files)${NC}"

# Generate encryption key directly (no host files)
ENCRYPTION_KEY=$(openssl rand -base64 32)
echo -e "${GREEN}✅ Generated encryption key${NC}"

# Create timestamped secret name
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ENCRYPTION_SECRET_NAME="data_source_encryption_key_${TIMESTAMP}"

# Clean up old secrets for this environment
echo -e "${YELLOW}🧹 Cleaning up old secrets for $MIX_ENV...${NC}"
docker secret ls --format "{{.Name}}" | grep "^data_source_encryption_key_" | while read secret; do
    docker secret rm "$secret" 2>/dev/null || true
done
docker secret ls --format "{{.Name}}" | grep "^secret_key_base_" | while read secret; do
    docker secret rm "$secret" 2>/dev/null || true
done

echo -e "${BLUE}🔑 Creating encryption key secret: $ENCRYPTION_SECRET_NAME${NC}"
echo "$ENCRYPTION_KEY" | docker secret create "$ENCRYPTION_SECRET_NAME" - >/dev/null

# Generate SECRET_KEY_BASE based on environment
if [ "$MIX_ENV" = "prod" ]; then
    # For production, generate a secure key
    SECRET_KEY_BASE=$(openssl rand -base64 64)
else
    # For dev/test, generate a key
    SECRET_KEY_BASE=$(openssl rand -base64 64)
fi

SECRET_SECRET_NAME="secret_key_base_${TIMESTAMP}"
echo -e "${BLUE}🔑 Creating secret key base secret: $SECRET_SECRET_NAME${NC}"
echo "$SECRET_KEY_BASE" | docker secret create "$SECRET_SECRET_NAME" - >/dev/null

echo
echo -e "${GREEN}✅ Docker Swarm secrets created successfully!${NC}"
echo
echo -e "${BLUE}📋 Created secrets:${NC}"
echo "  • $ENCRYPTION_SECRET_NAME"
echo "  • $SECRET_SECRET_NAME"

# Export for use by other scripts
export ENCRYPTION_SECRET_NAME
export SECRET_SECRET_NAME  
export ENCRYPTION_KEY
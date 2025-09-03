#!/bin/bash
set -e

# Derive environment from MIX_ENV or parameter (default: dev)
ENV_NAME="${MIX_ENV:-${1:-dev}}"
KEY_FOLDER="alerts-${ENV_NAME}"

# Configuration
KEY_DIR="${ENCRYPTION_KEY_DIR:-$HOME/.${KEY_FOLDER}}"
KEY_FILE="$KEY_DIR/encryption_key.txt"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

# Create directory if it doesn't exist
mkdir -p "$KEY_DIR"

# Check if key already exists
if [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}Key already exists at: $KEY_FILE${NC}"
    exit 0
fi

# Generate new key
KEY=$(openssl rand -base64 32)
echo "$KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

echo -e "${GREEN}✓ Generated encryption key: $KEY_FILE${NC}"
echo "To use: export DATA_SOURCE_ENCRYPTION_KEY=\$(cat $KEY_FILE)"
#!/bin/bash
set -e

# Derive environment from MIX_ENV or parameter (default: dev)
MIX_ENV="${MIX_ENV:-${1:-dev}}"
export MIX_ENV
KEY_FOLDER="alerts-${MIX_ENV}"

# Configuration
KEY_DIR="${ENCRYPTION_KEY_DIR:-$HOME/.${KEY_FOLDER}}"
KEY_FILE="$KEY_DIR/encryption_key.txt"
OLD_KEY_FILE="$KEY_DIR/encryption_key_old.txt"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

echo "🔄 Encryption Key Rotation ($MIX_ENV -> $KEY_FOLDER)"
echo "=========================="

# Check if current key exists
if [ ! -f "$KEY_FILE" ]; then
    echo -e "${RED}✗ Error: No key at $KEY_FILE to rotate, you haven init'd the environment${NC}"
    exit 1
fi

# Read current key from file
OLD_KEY=$(cat "$KEY_FILE")
echo "Current key loaded from: $KEY_FILE"

# Confirm rotation
echo -e "${YELLOW}⚠ This will:"
echo "  1. Generate a new encryption key"
echo "  2. Re-encrypt all existing passwords with the new key" 
echo "  3. Update the database with new encrypted values"
echo "  4. Backup the old key for recovery${NC}"
echo
confirm_or_exit "Are you sure you want to rotate the encryption key? (y/N): " "Key rotation cancelled."

# Generate new key
NEW_KEY=$(openssl rand -base64 32)
echo -e "${BLUE}📝 Generated new encryption key${NC}"

# Backup old key
cp "$KEY_FILE" "$OLD_KEY_FILE"
echo -e "${GREEN}✓ Backed up old key to: $OLD_KEY_FILE${NC}"

# Store new key
echo "$NEW_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo -e "${GREEN}✓ Stored new key at: $KEY_FILE${NC}"

# Export both keys for the rotation script
export DATA_SOURCE_ENCRYPTION_KEY="$NEW_KEY"
export OLD_DATA_SOURCE_ENCRYPTION_KEY="$OLD_KEY"

echo -e "${BLUE}🔄 Running password re-encryption...${NC}"

# Get the correct service name for the environment
SERVICE_NAME=$(get_service_name "$MIX_ENV")

# Run the Elixir key rotation script
docker-compose run --rm -T \
    --entrypoint="" \
    -e MIX_ENV="$MIX_ENV" \
    -e DATA_SOURCE_ENCRYPTION_KEY="$NEW_KEY" \
    -e OLD_DATA_SOURCE_ENCRYPTION_KEY="$OLD_KEY" \
    $SERVICE_NAME mix run scripts/rotate_encryption_key.exs "$OLD_KEY" "$NEW_KEY"

echo
echo "✅ Key rotation completed successfully, Old key backed up at: $OLD_KEY_FILE!"
echo ""
echo -e "To restart with the new key, ${YELLOW}run the startup script in bin/$MIX_ENV/startup.sh${NC}"
echo ""
echo -e "⚠ Keep both keys safe until you're sure the rotation was successful!"

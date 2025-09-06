#!/bin/bash
set -e

# Rotation script for encryption keys
# Usage: ./bin/helpers/crypto/rotate_encryption_key.sh [environment] [old_key] [new_key]

ENV="${1:-dev}"
OLD_KEY="$2"
NEW_KEY="$3"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

if [ -z "$OLD_KEY" ] || [ -z "$NEW_KEY" ]; then
    print_status "❌ Usage: $0 [environment] [old_key] [new_key]" $RED
    exit 1
fi

print_status "🔄 Rotating encryption keys for $ENV environment" $BLUE
echo "=============================================="

print_status "⚠️  IMPORTANT: Backup your database before proceeding!" $YELLOW
read -p "Continue with encryption key rotation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rotation cancelled."
    exit 1
fi

print_status "🔄 Running encryption key rotation..." $YELLOW

# Run the Elixir rotation script
MIX_ENV="$ENV" docker-compose run --rm --entrypoint="" "web-$ENV" mix run scripts/rotate_encryption_key.exs "$OLD_KEY" "$NEW_KEY"

if [ $? -eq 0 ]; then
    print_status "✅ Encryption key rotation completed successfully!" $GREEN
    echo
else
    print_status "❌ Encryption key rotation failed!" $RED
    exit 1
fi
#!/bin/bash
set -e

# Setup Master Password Script
# Usage: ./setup_master_password.sh <environment>
# Interactive password setup for Docker secrets

ENVIRONMENT="${1:-dev}"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

# Validate environment
case "$ENVIRONMENT" in
    dev|test|prod) ;;
    *) 
        print_status "❌ Invalid environment: $ENVIRONMENT. Must be dev, test, or prod" $RED
        exit 1
        ;;
esac

print_status "🔐 Setting up master password for $ENVIRONMENT environment" $BLUE

# Check if Docker Swarm is initialized
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
    print_status "❌ Docker Swarm is not initialized" $RED
    echo "Initialize with: docker swarm init"
    exit 1
fi

# Interactive password input
echo "Enter master password (minimum 8 characters):"
read -s password
echo
echo "Confirm master password:"
read -s password_confirm
echo

# Validate passwords match
if [ "$password" != "$password_confirm" ]; then
    print_status "❌ Passwords do not match" $RED
    exit 1
fi

# Validate password length
if [ ${#password} -lt 8 ]; then
    print_status "❌ Password must be at least 8 characters" $RED
    exit 1
fi

# Generate timestamped secret name
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SECRET_NAME="master_password_${TIMESTAMP}"

# Hash password with SHA-256 before storing (security best practice)
PASSWORD_HASH=$(echo -n "$password" | sha256sum | cut -d' ' -f1)

print_status "🔑 Creating Docker secret: $SECRET_NAME" $BLUE

# Create Docker secret
echo "$PASSWORD_HASH" | docker secret create "$SECRET_NAME" -

# Clean up old master password secrets for this environment
print_status "🧹 Cleaning up old master password secrets..." $YELLOW
OLD_SECRETS=$(docker secret ls --format "{{.Name}}" | grep "^master_password_" | grep -v "$SECRET_NAME" || true)
if [ -n "$OLD_SECRETS" ]; then
    echo "$OLD_SECRETS" | while read -r old_secret; do
        if docker secret rm "$old_secret" 2>/dev/null; then
            echo "  • Removed: $old_secret"
        fi
    done
else
    echo "  • No old secrets to clean up"
fi

print_status "✅ Master password secret created: $SECRET_NAME" $GREEN
print_status "⚠️  Remember to restart the environment to use new secret:" $YELLOW
echo "   ./bin/startup.sh $ENVIRONMENT --reboot"

# Clear sensitive variables
unset password password_confirm PASSWORD_HASH
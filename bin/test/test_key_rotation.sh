#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

print_status "🔄 Testing Key Rotation" $YELLOW

# Stop any running test containers first
docker-compose --profile testing stop web-test > /dev/null 2>&1 || true

# Initialize test key
./bin/helpers/crypto/init_encryption_key.sh test

# Test key rotation
print_status "Rotating key..." $YELLOW
if echo "y" | ./bin/helpers/crypto/rotate_encryption_key.sh test; then
    print_status "✅ Key rotation test passed!" $GREEN
else
    print_status "❌ Key rotation test failed!" $RED
    exit 1
fi
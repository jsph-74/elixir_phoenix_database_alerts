#!/bin/bash
set -e

# Get environment parameter (default: dev)
ENV="${1:-dev}"

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

print_status "🚀 Initializing $ENV environment" $BLUE
echo "=============================================="
echo

# Step 1: Create Docker Swarm secrets
print_status "Step 1: Creating Docker Swarm secrets..." $YELLOW
source ./bin/helpers/crypto/secrets.sh "$ENV"

# Step 2: Generate Docker Compose file  
print_status "Step 2: Generating Docker Compose file..." $YELLOW
./bin/helpers/docker/create_docker_compose.sh "$ENV"

# Step 3: Build Docker image
print_status "Step 3: Building Docker image..." $YELLOW
./bin/build.sh "$ENV"

print_status "✅ Environment $ENV initialized successfully!" $GREEN
echo 
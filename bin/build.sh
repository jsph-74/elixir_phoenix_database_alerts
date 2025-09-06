#!/bin/bash
set -e

# Get environment parameter (default: dev)
ENV="${1:-dev}"

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

# Build the web service for the specified environment
print_status "Building elixir_alerts-web-$ENV..." $BLUE
docker build --no-cache -t elixir_alerts-web-$ENV -f Dockerfile.PhoenixAlerts .

# Build Playwright image for dev and test environments only
if [ "$ENV" = "dev" ] || [ "$ENV" = "test" ]; then
    print_status "Building elixir_alerts-playwright..." $BLUE
    docker build --no-cache -t elixir_alerts-playwright:latest -f Dockerfile.Playwright .
fi

print_status "✅ Build complete for $ENV!" $GREEN
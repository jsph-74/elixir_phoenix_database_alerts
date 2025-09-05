#!/bin/bash
set -e

# Get environment parameter (default: dev)
ENV="${1:-dev}"

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

print_status "🔨 Building $ENV environment" $YELLOW

# Build the web service for the specified environment
print_status "Building elixir_alerts-web-$ENV..." $BLUE
docker build --no-cache -t elixir_alerts-web-$ENV -f Dockerfile.PhoenixAlerts .

print_status "✅ Build complete for $ENV!" $GREEN
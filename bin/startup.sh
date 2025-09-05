#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

# Get environment parameter (default: dev)
ENV="${1:-dev}"

# Get port for environment
PORT=$(get_http_port "$ENV")

echo "🚀 Starting $ENV environment with Docker Stack..."
docker stack deploy -c docker-compose-$ENV.yaml alerts-$ENV
echo "✅ $ENV available at http://localhost:$PORT"
#!/bin/bash
# Join Docker Stack services to sample database network
# Usage: ./bin/helpers/docker/join_sample_db_network.sh [environment]

set -e

ENV="${1:-dev}"

echo "🔗 Joining $ENV environment to sample database network..."

# Wait for web service to be running
echo "⏳ Waiting for web service to be ready..."
for i in {1..30}; do
    WEB_CONTAINER=$(docker ps -q -f "name=alerts-${ENV}_web-${ENV}" | head -1)
    if [ -n "$WEB_CONTAINER" ]; then
        echo "Found web container: $WEB_CONTAINER"
        break
    fi
    echo "Waiting for web container... ($i/30)"
    sleep 2
done

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not found for environment $ENV"
    exit 1
fi

# Join sample database network
if docker network connect alerts-shared "$WEB_CONTAINER" 2>/dev/null; then
    echo "✅ Joined $ENV environment to sample database network"
else
    echo "⚠️  Container already connected to alerts-shared network"
fi
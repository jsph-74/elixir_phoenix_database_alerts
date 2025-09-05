#!/bin/bash
set -e

echo "🚀 Starting external test databases..."
docker-compose -f docker-compose.testdbs.yaml up -d

echo "⏳ Waiting for databases..."
sleep 10
echo "✅ Test databases ready"
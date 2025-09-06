#!/bin/bash
set -e

echo "🚀 Starting sample databases..."
docker-compose -f docker-compose.sample-dbs.yaml up -d

echo "⏳ Waiting for databases to be ready..."

# Wait for MySQL to be ready (port 3306)
until docker exec $(docker ps -q -f "name=mysql") mysqladmin ping -h"127.0.0.1" --silent 2>/dev/null; do
  echo "Waiting for MySQL (e-commerce sample db)..."
  sleep 2
done

# Wait for PostgreSQL to be ready (internal port 5432) 
until docker exec $(docker ps -q -f "name=postgres") pg_isready -h 127.0.0.1 -p 5432 -U postgres 2>/dev/null; do
  echo "Waiting for PostgreSQL (portfolios sample db)..."
  sleep 2
done

echo "✅ Sample Test databases ready"
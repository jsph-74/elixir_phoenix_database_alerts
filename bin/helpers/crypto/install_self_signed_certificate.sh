#!/bin/bash
set -e

# Host wrapper script for SSL certificate generation
# This script calls the container-internal SSL generation script

# Source shared functions
source "$(dirname "$0")/../functions.sh"

ENVIRONMENT="${1:-dev}"
SERVICE_NAME=$(get_service_name "$ENVIRONMENT")

echo "🔐 Generating SSL certificate for $ENVIRONMENT environment..."

# Run the container-internal SSL generation script in the RUNNING stack service
exec_in_stack_service "$ENVIRONMENT" ./bin/generate_ssl_cert.sh "$ENVIRONMENT"

echo ""
echo "✅ SSL certificate generated in container!"
echo "🔄 Restarting $ENVIRONMENT service to apply SSL configuration..."

# Get the script directory to call startup.sh with correct path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
"$SCRIPT_DIR/startup.sh" "$ENVIRONMENT" --reboot
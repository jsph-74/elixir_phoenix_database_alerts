#!/bin/bash
set -e

# Get environment parameter (default: dev)
ENV="${1:-dev}"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

echo "🔄 Generating docker-compose-${ENV}.yaml from template..."

# Get ports for environment
HTTP_PORT=$(get_http_port "$ENV")
HTTPS_PORT=$(get_https_port "$ENV")

# Set database port based on environment
case "$ENV" in
    dev) DB_PORT="5430" ;;
    test) DB_PORT="5431" ;;
    prod) DB_PORT="5432" ;;
    *) DB_PORT="5432" ;;
esac

# Check if required secret variables are set
if [ -z "$ENCRYPTION_SECRET_NAME" ] || [ -z "$SECRET_SECRET_NAME" ]; then
    print_status "❌ Secret names not set. Run create_secrets.sh first" $RED
    exit 1
fi

# Generate environment-specific docker-compose file from template
# Use multiple sed commands to avoid character escaping issues
cp docker-compose.tpl.yaml docker-compose-${ENV}.yaml
sed -i "" "s/{{ENV}}/$ENV/g" docker-compose-${ENV}.yaml
sed -i "" "s/{{HTTP_PORT}}/$HTTP_PORT/g" docker-compose-${ENV}.yaml
sed -i "" "s/{{HTTPS_PORT}}/$HTTPS_PORT/g" docker-compose-${ENV}.yaml
sed -i "" "s/{{DB_PORT}}/$DB_PORT/g" docker-compose-${ENV}.yaml
sed -i "" "s/{{ENCRYPTION_SECRET_NAME}}/$ENCRYPTION_SECRET_NAME/g" docker-compose-${ENV}.yaml
sed -i "" "s/{{SECRET_SECRET_NAME}}/$SECRET_SECRET_NAME/g" docker-compose-${ENV}.yaml

# Handle ENCRYPTION_KEY_VALUE separately with a different delimiter to avoid base64 issues
sed -i "" "s|{{ENCRYPTION_KEY_VALUE}}|$ENCRYPTION_KEY|g" docker-compose-${ENV}.yaml

print_status "✅ Generated docker-compose-${ENV}.yaml with:" $GREEN
echo "  • Environment: $ENV"
echo "  • HTTP Port: $HTTP_PORT"  
echo "  • HTTPS Port: $HTTPS_PORT"
echo "  • Database Port: $DB_PORT"
echo "  • Encryption Secret: $ENCRYPTION_SECRET_NAME"
echo "  • Secret Key Secret: $SECRET_SECRET_NAME"
#!/bin/bash
set -e

# Install Custom SSL Certificate Script
# Usage: ./install_custom_certificate.sh <environment> <cert_path> <key_path>
# Example: ./install_custom_certificate.sh prod /path/to/cert.pem /path/to/key.pem

# Check arguments
if [ $# -ne 3 ]; then
    echo "❌ Usage: $0 <environment> <cert_path> <key_path>"
    echo "   environment: dev, test, or prod"
    echo "   cert_path: path to certificate file (.pem)"
    echo "   key_path: path to private key file (.pem)"
    echo ""
    echo "Example: $0 prod /etc/letsencrypt/live/example.com/fullchain.pem /etc/letsencrypt/live/example.com/privkey.pem"
    exit 1
fi

ENVIRONMENT="$1"
CERT_PATH="$2"
KEY_PATH="$3"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

# Validate environment
case "$ENVIRONMENT" in
    dev|test|prod) ;;
    *) 
        print_status "❌ Invalid environment: $ENVIRONMENT. Must be dev, test, or prod" $RED
        exit 1
        ;;
esac

# Validate certificate files exist
if [ ! -f "$CERT_PATH" ]; then
    print_status "❌ Certificate file not found: $CERT_PATH" $RED
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    print_status "❌ Private key file not found: $KEY_PATH" $RED
    exit 1
fi

# Validate certificate files are readable
if [ ! -r "$CERT_PATH" ]; then
    print_status "❌ Certificate file not readable: $CERT_PATH" $RED
    exit 1
fi

if [ ! -r "$KEY_PATH" ]; then
    print_status "❌ Private key file not readable: $KEY_PATH" $RED
    exit 1
fi

print_status "🔐 Installing custom SSL certificate for $ENVIRONMENT environment" $BLUE
echo "📁 Certificate: $CERT_PATH"
echo "🔑 Private key: $KEY_PATH"

# Determine volume name based on environment
VOLUME_NAME="alerts-${ENVIRONMENT}_alerts-ssl-${ENVIRONMENT}"

# Check if volume exists
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
    print_status "❌ SSL volume not found: $VOLUME_NAME" $RED
    echo "💡 Start the $ENVIRONMENT environment first: ./bin/startup.sh $ENVIRONMENT"
    exit 1
fi

# Get absolute paths to avoid mount issues
CERT_ABS_PATH=$(realpath "$CERT_PATH")
KEY_ABS_PATH=$(realpath "$KEY_PATH")

echo "📦 Copying certificates to Docker volume..."

# Copy certificates to volume with proper permissions
docker run --rm \
    -v "$VOLUME_NAME:/ssl" \
    -v "$CERT_ABS_PATH:/tmp/cert.pem:ro" \
    -v "$KEY_ABS_PATH:/tmp/key.pem:ro" \
    alpine sh -c "
        cp /tmp/cert.pem /ssl/$ENVIRONMENT/ && 
        cp /tmp/key.pem /ssl/$ENVIRONMENT/ && 
        chmod 644 /ssl/$ENVIRONMENT/cert.pem && 
        chmod 600 /ssl/$ENVIRONMENT/key.pem &&
        echo '✅ Certificates copied successfully' &&
        echo '📁 Certificate: /ssl/$ENVIRONMENT/cert.pem' &&
        echo '🔑 Private key: /ssl/$ENVIRONMENT/key.pem'
    "

# Verify certificates were installed
echo ""
echo "🔍 Verifying certificate installation..."
docker run --rm -v "$VOLUME_NAME:/ssl" alpine ls -la "/ssl/$ENVIRONMENT/" | grep -E "\.(pem|conf)$" || true

# Show certificate details
echo ""
echo "📋 Certificate information:"
docker run --rm -v "$VOLUME_NAME:/ssl" alpine sh -c "
    openssl x509 -in /ssl/$ENVIRONMENT/cert.pem -text -noout | grep -E '(Subject:|Issuer:|Not Before|Not After|DNS:|IP Address:)' 2>/dev/null || echo 'Could not parse certificate details'
"

echo ""
print_status "✅ Custom SSL certificate installed successfully!" $GREEN
echo "🚀 Restart the $ENVIRONMENT environment to apply:"
echo "   ./bin/startup.sh $ENVIRONMENT --reboot"
#!/bin/bash
set -e

# SSL Setup Script for Phoenix Alerts
# Usage: ./setup_ssl.sh [env]
# Configures Phoenix to use SSL with existing certificates

# Derive environment from MIX_ENV or parameter (default: dev)
MIX_ENV="${MIX_ENV:-${1:-dev}}"
export MIX_ENV

CERT_DIR="/app/priv/ssl/${MIX_ENV}"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"
CONFIG_FILE="/app/config/runtime.exs"

# Source shared functions
source "$(dirname "$0")/../functions.sh"

echo "🔧 Setting up SSL for Phoenix Alerts ($MIX_ENV environment)..."

# Check if certificates exist
if [[ ! -f "$CERT_FILE" ]]; then
    echo "❌ Certificate file not found: $CERT_FILE"
    echo "💡 Generate self-signed certificate first:"
    echo "   ./bin/helpers/crypto/generate_self_signed_cert.sh $MIX_ENV"
    echo ""
    echo "💡 Or copy your CA-signed certificates to:"
    echo "   - Certificate: $CERT_FILE"
    echo "   - Private key: $KEY_FILE"
    exit 1
fi

if [[ ! -f "$KEY_FILE" ]]; then
    echo "❌ Private key file not found: $KEY_FILE"
    echo "💡 Make sure both certificate and private key are present"
    exit 1
fi

# Verify certificate and key match
echo "🔍 Verifying certificate and private key..."
CERT_HASH=$(openssl x509 -noout -modulus -in "$CERT_FILE" | openssl md5)
KEY_HASH=$(openssl rsa -noout -modulus -in "$KEY_FILE" | openssl md5)

if [[ "$CERT_HASH" != "$KEY_HASH" ]]; then
    echo "❌ Certificate and private key do not match!"
    echo "Certificate hash: $CERT_HASH"
    echo "Key hash: $KEY_HASH"
    exit 1
fi

echo "✅ Certificate and private key match"

# Check certificate permissions
echo "🔒 Checking certificate permissions..."
KEY_PERMS=$(stat -f "%A" "$KEY_FILE" 2>/dev/null || stat -c "%a" "$KEY_FILE" 2>/dev/null)
if [[ "$KEY_PERMS" != "600" ]]; then
    echo "🔧 Fixing private key permissions..."
    chmod 600 "$KEY_FILE"
fi

# Display certificate info
echo "📋 Certificate information:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -E "(Subject:|Not Before|Not After|DNS:|IP Address:)" || true

# Check if certificate is expired or expires soon
EXPIRE_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
EXPIRE_EPOCH=$(date -d "$EXPIRE_DATE" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$EXPIRE_DATE" +%s 2>/dev/null)
CURRENT_EPOCH=$(date +%s)
DAYS_UNTIL_EXPIRE=$(( (EXPIRE_EPOCH - CURRENT_EPOCH) / 86400 ))

if [[ $DAYS_UNTIL_EXPIRE -lt 0 ]]; then
    echo "⚠️  WARNING: Certificate has expired!"
elif [[ $DAYS_UNTIL_EXPIRE -lt 30 ]]; then
    echo "⚠️  WARNING: Certificate expires in $DAYS_UNTIL_EXPIRE days"
else
    echo "✅ Certificate is valid for $DAYS_UNTIL_EXPIRE days"
fi

# Phoenix SSL configuration is environment-aware in runtime.exs
echo "⚙️  Phoenix SSL configuration is already environment-aware"
echo "📝 SSL will use certificates from: $CERT_DIR/"

# Verify Phoenix config references environment-specific paths
if grep -q "ssl/#{ssl_env}" "$CONFIG_FILE" 2>/dev/null; then
    echo "✅ Phoenix configuration is properly using environment-specific SSL paths"
else
    echo "⚠️  Phoenix configuration may need manual update for environment-specific SSL paths"
    echo "💡 Ensure runtime.exs uses: /app/priv/ssl/#{ssl_env}/cert.pem"
fi

# Set environment variables for SSL
echo "🌍 Setting SSL environment variables..."
HTTP_PORT=$(get_http_port "$MIX_ENV")
HTTPS_PORT=$(get_https_port "$MIX_ENV")
HTTP_URL=$(get_base_url "$MIX_ENV" "http")
HTTPS_URL=$(get_base_url "$MIX_ENV" "https")

export ENABLE_SSL=true
export HTTPS_PORT="$HTTPS_PORT"
export HTTP_PORT="$HTTP_PORT"

echo ""
echo "🎉 SSL setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Set environment variables:"
echo "   export ENABLE_SSL=true"
echo "   export HTTPS_PORT=$HTTPS_PORT"
echo "   export HTTP_PORT=$HTTP_PORT"
echo ""
echo "2. Start Phoenix with:"
echo "   MIX_ENV=$MIX_ENV mix phx.server"
echo ""
echo "3. Access your app at:"
echo "   🔒 $HTTPS_URL"
echo "   📄 $HTTP_URL (redirects to HTTPS)"
echo ""
echo "📁 SSL files located at:"
echo "   - Certificate: $CERT_FILE"
echo "   - Private key: $KEY_FILE"
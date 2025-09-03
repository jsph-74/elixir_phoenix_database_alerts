#!/bin/bash
set -e

# Container-internal SSL certificate generation script
# This script runs inside the Phoenix container and generates self-signed certificates
# Usage: ./bin/generate_ssl_cert.sh [environment]

ENVIRONMENT="${1:-dev}"
CERT_DIR="/app/priv/ssl/${ENVIRONMENT}"
DOMAIN="${SSL_DOMAIN:-localhost}"
ADDITIONAL_DOMAINS="${SSL_ADDITIONAL_DOMAINS:-localhost,127.0.0.1,*.local}"

echo "🔐 Generating self-signed SSL certificate for ${ENVIRONMENT} environment..."
echo "📍 Primary domain: ${DOMAIN}"
echo "📍 Additional domains: ${ADDITIONAL_DOMAINS}"
echo "📁 Certificate directory: ${CERT_DIR}"

# SSL directory should already exist from Dockerfile
echo "📁 Certificate directory: $CERT_DIR"

# Create OpenSSL config for SAN (Subject Alternative Names)
cat > "${CERT_DIR}/cert.conf" << EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C=US
ST=Development
L=Local
O=Alerts Development
CN=${DOMAIN}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
EOF

# Add SAN entries
IFS=',' read -ra DOMAINS <<< "$ADDITIONAL_DOMAINS"
counter=1
for domain in "${DOMAINS[@]}"; do
    domain=$(echo "$domain" | xargs) # trim whitespace
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP.${counter} = ${domain}" >> "${CERT_DIR}/cert.conf"
    else
        echo "DNS.${counter} = ${domain}" >> "${CERT_DIR}/cert.conf"
    fi
    ((counter++))
done

# Generate private key
openssl genrsa -out "${CERT_DIR}/key.pem" 2048

# Generate certificate
openssl req -new -x509 -key "${CERT_DIR}/key.pem" -out "${CERT_DIR}/cert.pem" -days 365 -config "${CERT_DIR}/cert.conf" -extensions v3_req

# Set permissions
chmod 600 "${CERT_DIR}/key.pem"
chmod 644 "${CERT_DIR}/cert.pem"
chmod 644 "${CERT_DIR}/cert.conf"

# Verify certificate
echo ""
echo "✅ SSL certificate generated successfully!"
echo "📁 Certificate: ${CERT_DIR}/cert.pem"
echo "🔑 Private key: ${CERT_DIR}/key.pem"
echo ""
echo "🔍 Certificate details:"
openssl x509 -in "${CERT_DIR}/cert.pem" -text -noout | grep -A 3 "Subject Alternative Name" || echo "  No SAN found"
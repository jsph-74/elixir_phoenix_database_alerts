#!/bin/bash
set -e

# Get existing secret name for a given environment and secret type
# Usage: get_secret_name.sh <env> <secret_type>
# Returns the full secret name or empty string if not found

ENV="$1"
SECRET_TYPE="$2"

if [ -z "$ENV" ] || [ -z "$SECRET_TYPE" ]; then
    echo "Usage: $0 <env> <secret_type>"
    echo "Secret types: db_encryption_key, secret_key_base, master_password"
    exit 1
fi

case "$SECRET_TYPE" in
    db_encryption_key)
        docker secret ls --format "{{.Name}}" | grep "^data_source_encryption_key_" | head -n 1 || echo ""
        ;;
    secret_key_base)
        docker secret ls --format "{{.Name}}" | grep "^secret_key_base_" | head -n 1 || echo ""
        ;;
    master_password)
        docker secret ls --format "{{.Name}}" | grep "^master_password_" | head -n 1 || echo ""
        ;;
    *)
        echo "Unknown secret type: $SECRET_TYPE" >&2
        exit 1
        ;;
esac
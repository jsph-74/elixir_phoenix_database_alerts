#!/bin/bash
set -e

# Create production secrets directory
mkdir -p ~/.alerts-prod

# Generate SECRET_KEY_BASE if it doesn't exist
if [ ! -f ~/.alerts-prod/secret_key_base.txt ]; then
    docker-compose run --rm --entrypoint="" web-prod mix phx.gen.secret > ~/.alerts-prod/secret_key_base.txt
    echo "✅ SECRET_KEY_BASE generated and saved to ~/.alerts-prod/secret_key_base.txt"
else
    echo "✅ SECRET_KEY_BASE already exists"
fi

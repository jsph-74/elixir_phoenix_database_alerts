#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored status messages
print_status() {
    echo -e "${2}${1}${NC}"
}

# Ask for confirmation with custom message
confirm_or_exit() {
    local message="${1:-Do you want to proceed? (y/N): }"
    local cancel_message="${2:-Operation cancelled.}"
    
    read -p "$(print_status "$message" $YELLOW)" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "$cancel_message"
        exit 1
    fi
}

# Get docker service name for environment
get_service_name() {
    local env="${1:-dev}"
    case "$env" in
        dev) echo "web-dev" ;;
        test) echo "web-test" ;;
        prod) echo "web-prod" ;;
        *) echo "web-dev" ;;
    esac
}


# Get HTTP port for environment
get_http_port() {
    local env="${1:-dev}"
    case "$env" in
        dev) echo "4000" ;;
        test) echo "4002" ;;
        prod) echo "4004" ;;
        *) echo "4000" ;;
    esac
}

# Get HTTPS port for environment  
get_https_port() {
    local env="${1:-dev}"
    case "$env" in
        dev) echo "4001" ;;
        test) echo "4003" ;;
        prod) echo "4005" ;;
        *) echo "4001" ;;
    esac
}

# Get base URL for environment
get_base_url() {
    local env="${1:-dev}"
    local protocol="${2:-http}"
    local port
    
    if [[ "$protocol" == "https" ]]; then
        port=$(get_https_port "$env")
    else
        port=$(get_http_port "$env")
    fi
    
    echo "${protocol}://localhost:${port}"
}

# Docker container cleanup function
docker_cleanup() {
    print_status "🧹 Cleaning up containers..." $YELLOW
    docker container prune -f > /dev/null 2>&1 
}

# Check if Docker Swarm secrets are initialized for environment
check_swarm_secrets() {
    local env="${1:-dev}"
    
    # Check if Docker Swarm is initialized
    if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
        print_status "❌ Docker Swarm is not initialized" $RED
        echo "Please run: ./bin/helpers/crypto/secrets.sh $env"
        exit 1
    fi

    # Check if secrets exist in Docker
    local encryption_secrets=$(docker secret ls --format "{{.Name}}" | grep "^data_source_encryption_key_" | wc -l)
    local secret_key_secrets=$(docker secret ls --format "{{.Name}}" | grep "^secret_key_base_" | wc -l)
    
    if [ "$encryption_secrets" -eq 0 ] || [ "$secret_key_secrets" -eq 0 ]; then
        print_status "❌ No Docker secrets found" $RED
        echo "Please run: ./bin/helpers/crypto/secrets.sh $env"
        exit 1
    fi
}

# Get current secret names for environment from Docker
get_secret_names() {
    local env="${1:-dev}"
    
    # Get the most recent encryption key secret (by timestamp)
    ENCRYPTION_SECRET=$(docker secret ls --format "{{.Name}}" | grep "^data_source_encryption_key_" | sort -r | head -1)
    
    # Get the most recent secret key base secret (by timestamp)  
    SECRET_KEY_SECRET=$(docker secret ls --format "{{.Name}}" | grep "^secret_key_base_" | sort -r | head -1)
    
    if [ -z "$ENCRYPTION_SECRET" ] || [ -z "$SECRET_KEY_SECRET" ]; then
        print_status "❌ No secrets found for $env environment" $RED
        echo "Please run: ./bin/helpers/crypto/secrets.sh $env"
        exit 1
    fi
    
    print_status "📋 Using secrets:" $BLUE
    echo "  • Encryption: $ENCRYPTION_SECRET"
    echo "  • Secret Key: $SECRET_KEY_SECRET"
}

# Deploy application stack with Docker Swarm secrets
deploy_stack_with_secrets() {
    local env="${1:-dev}"
    
    # Create temporary compose file with current secret names and stack-compatible format
    local temp_compose="$(mktemp)"
    trap "rm -f $temp_compose" EXIT

    # Remove container names and profiles that aren't compatible with stack mode, update secret names
    sed -e "s/source: data_source_encryption_key/source: ${ENCRYPTION_SECRET}/" \
        -e "s/source: secret_key_base/source: ${SECRET_KEY_SECRET}/" \
        -e "s/^  data_source_encryption_key:$/  ${ENCRYPTION_SECRET}:/" \
        -e "s/^  secret_key_base:$/  ${SECRET_KEY_SECRET}:/" \
        -e "/container_name:/d" \
        -e "/profiles:/,+1d" \
        docker-compose.yaml > "$temp_compose"

    print_status "🚀 Deploying application stack..." $BLUE
    if docker stack deploy -c "$temp_compose" alerts 2>/dev/null; then
        print_status "✅ Stack deployed successfully!" $GREEN
    else
        print_status "❌ Stack deployment failed, trying with compose validation..." $YELLOW
        echo "Compose file issues:"
        docker-compose -f "$temp_compose" config --quiet || docker-compose -f "$temp_compose" config
        exit 1
    fi
}

# Execute command in running stack service
exec_in_stack_service() {
    local env="${1:-dev}"
    local service_name="web-${env}"
    shift
    
    # Get the container ID for the stack service
    local container_id=$(docker ps --filter "name=alerts-${env}_${service_name}" --format "{{.ID}}" | head -1)
    
    if [ -z "$container_id" ]; then
        print_status "❌ Service alerts-${env}_${service_name} not running" $RED
        echo "Please start the environment first: ./bin/startup.sh ${env}"
        exit 1
    fi
    
    docker exec "$container_id" "$@"
}
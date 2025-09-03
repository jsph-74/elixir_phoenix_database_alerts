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
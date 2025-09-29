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

# Check if container is running for given environment
check_container_running() {
    local env="${1:-dev}"
    if ! docker ps -q -f "name=alerts-${env}_web-${env}" | grep -q .; then
        print_status "❌ Container alerts-${env}_web-${env} is not running" $RED
        echo "Start it first: ./bin/startup.sh $env"
        exit 1
    fi
}

# Initialize Docker Swarm if not already active
init_docker_swarm() {
    if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "^active$"; then
        docker swarm init --advertise-addr 127.0.0.1 2>/dev/null || true
    fi
}

# Wait for container to be fully ready (migrations complete)
wait_for_container_ready() {
    local env="${1:-dev}"
    local port=$(get_http_port "$env")
    
    echo "⏳ Waiting for container to be fully ready..."
    for i in {1..30}; do
        if curl -s -f "http://localhost:$port" >/dev/null 2>&1; then
            echo "✅ Container is ready"
            return 0
        fi
        echo "Waiting for container... ($i/30)"
        sleep 2
    done
    
    print_status "❌ Container failed to become ready" $RED
    exit 1
}

# Execute command in a running stack service
exec_in_stack_service() {
    local env="${1:-dev}"
    local service_name=$(get_service_name "$env")
    local stack_name="alerts-$env"
    shift

    # Get the first running task ID for the service
    local task_id=$(docker service ps --filter "desired-state=running" --format "{{.ID}}" "${stack_name}_${service_name}" | head -n1)

    if [ -z "$task_id" ]; then
        print_status "❌ No running tasks found for service ${stack_name}_${service_name}" $RED
        exit 1
    fi

    # Get the container ID from the task
    local container_id=$(docker inspect --format "{{.Status.ContainerStatus.ContainerID}}" "$task_id" 2>/dev/null)

    if [ -z "$container_id" ]; then
        print_status "❌ Could not find container for task $task_id" $RED
        exit 1
    fi

    echo "🔧 Executing in container: $@"
    docker exec "$container_id" "$@"
}
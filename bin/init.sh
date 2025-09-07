#!/bin/bash
set -e

# Parse arguments
PRUNE_DOCKER=false
ENV="dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prune)
            PRUNE_DOCKER=true
            shift
            ;;
        *)
            ENV="$1"
            shift
            ;;
    esac
done

# Source shared functions
source "$(dirname "$0")/helpers/functions.sh"

print_status "🚀 FULL SETUP: Complete $ENV environment deployment" $BLUE
echo "=============================================================="
echo
echo "This will:"
if [ "$PRUNE_DOCKER" = true ]; then
    echo "- Clean all Docker resources"
fi
    echo "- Start external sample databases (if not prod)"
    echo "- Create application secrets"
    echo "- Build $ENV environment"
    echo "- Start $ENV environment"

echo
confirm_or_exit "Proceed with full $ENV setup? (y/N): " "Setup cancelled."

# Clean Docker (optional)
if [ "$PRUNE_DOCKER" = true ]; then
    echo y | ./bin/helpers/docker/prune.sh 
else
    # Remove existing stack for this environment to avoid conflicts
    docker stack rm "alerts-${ENV}" 2>/dev/null || true
    sleep 5
fi

# Initialize Docker Swarm and create shared network (before sample databases)
if [ "$ENV" != "prod" ]; then
    # Initialize Docker Swarm
    init_docker_swarm

    # Create regular bridge network for sample databases (docker-compose compatibility)
    docker network create --driver bridge alerts-shared 2>/dev/null || echo "Network alerts-shared already exists"
    
    # Also, start external sample databases
    ./bin/helpers/db/start_sample_dbs.sh $ENV
fi

# Create application secrets
source ./bin/helpers/crypto/secrets.sh $ENV

# Generate compose file and build
./bin/helpers/docker/create_docker_compose.sh $ENV
./bin/build.sh $ENV
./bin/startup.sh $ENV

print_status "✅ Environment $ENV is ready!" $GREEN
echo
echo "  3. Access at: http://localhost:$(get_http_port "$ENV")"
echo

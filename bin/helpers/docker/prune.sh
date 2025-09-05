#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../functions.sh"

print_status "🗑️  DESTROYING ALL DOCKER RESOURCES" $RED
echo
echo "This will remove:"
echo "  • All containers (running and stopped)"
echo "  • All images" 
echo "  • All networks"
echo "  • All volumes"
echo "  • All build cache"
echo "  • All Docker Swarm secrets"
echo "  • Docker Swarm (leave swarm)"
echo ""
confirm_or_exit "Are you ABSOLUTELY SURE? This cannot be undone! (y/N): " "Aborted. Nothing was removed."

print_status "🛑 Removing all Docker Stacks..." $YELLOW
docker stack ls --format "{{.Name}}" | xargs -r -I {} docker stack rm {} 2>/dev/null || true

print_status "🛑 Leaving Docker Swarm..." $YELLOW
docker swarm leave --force 2>/dev/null || true

print_status "🛑 Removing all Docker Secrets..." $YELLOW
docker secret ls --format "{{.Name}}" | xargs -r docker secret rm 2>/dev/null || true

print_status "🛑 Stopping all containers..." $YELLOW
docker ps -aq | xargs -r docker stop

print_status "🛑 Removing all containers..." $YELLOW
docker ps -aq | xargs -r docker rm -f

print_status "🛑 Removing all images..." $YELLOW
docker images -aq | xargs -r docker rmi -f

print_status "🛑 Removing all networks..." $YELLOW
docker network ls -q --filter type=custom | xargs -r docker network rm 2>/dev/null || true

print_status "🛑 Removing all volumes..." $YELLOW
docker volume ls -q | xargs -r docker volume rm -f

print_status "🛑 Removing all build cache..." $YELLOW
docker builder prune -af

print_status "🛑 Final system prune..." $YELLOW
docker system prune -af --volumes

print_status "💥 ALL DOCKER RESOURCES DESTROYED!" $GREEN
print_status "Docker is now in a completely clean state." $BLUE
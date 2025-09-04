#!/bin/bash
set -e

check_db() {
    local service=$1
    local check_cmd=$2
    local retries=0
    local max_retries=15

    while [ $retries -lt $max_retries ]; do
        if eval "$check_cmd" >/dev/null 2>&1; then
            return 0
        fi
        retries=$((retries + 1))
        [ $retries -eq 1 ] && echo "Waiting for $service..." || echo -n "."
        sleep 1
    done
    echo " ❌ $service timeout"
    return 1
}

start_and_wait() {
    local services="$1"
    local checks="$2"
    local profile="$3"
    
    # Convert pipe-separated services to space-separated for docker-compose
    local docker_services=$(echo "$services" | tr '|' ' ')
    
    # Add profile if specified
    if [ -n "$profile" ]; then
        docker-compose --profile "$profile" up -d $docker_services >/dev/null 2>&1
    else
        docker-compose up -d $docker_services >/dev/null 2>&1
    fi
    
    IFS='|' read -ra SERVICE_ARRAY <<< "$services"
    IFS='|' read -ra CHECK_ARRAY <<< "$checks"
    
    for i in "${!SERVICE_ARRAY[@]}"; do
        if check_db "${SERVICE_ARRAY[i]}" "${CHECK_ARRAY[i]}"; then
            echo "✅ ${SERVICE_ARRAY[i]}"
        else
            exit 1
        fi
    done
}

PROFILE="${2:-}"

case "${1:-external_data}" in
    "alerts_db")
        start_and_wait "db" "docker-compose exec -T db pg_isready -U postgres" "$PROFILE"
        ;;
    "external_data")
        start_and_wait "test_mysql" "docker-compose exec -T test_mysql mysql -u root -pmysql -e 'SELECT 1' test" "$PROFILE"
        start_and_wait "test_postgres" "docker-compose exec -T test_postgres psql -U postgres -d test -c 'SELECT 1'" "$PROFILE"
        ;;
    *)
        echo "Usage: $0 [alerts_db|external_data] [profile]"
        echo "Examples:"
        echo "  $0 alerts_db production"
        echo "  $0 external_data testing"
        exit 1
        ;;
esac
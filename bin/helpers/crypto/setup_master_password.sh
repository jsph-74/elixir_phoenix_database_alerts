#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../functions.sh"

ENVIRONMENT="${1:-dev}"
PASSWORD="${2:-}"

print_status "🔐 Setting up Master Password for $ENVIRONMENT environment" $YELLOW

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
    print_status "❌ Invalid environment: $ENVIRONMENT" $RED
    echo "Usage: $0 [dev|test|prod] [password]"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Interactive password prompt"
    echo "  $0 prod \"secure_password\"  # Non-interactive with password"
    exit 1
fi

# Check if environment is running
check_environment_running() {
    case $ENVIRONMENT in
        dev)
            if ! curl -s http://localhost:4000 > /dev/null 2>&1; then
                print_status "❌ Development environment not running" $RED
                echo "Please start dev environment first:"
                echo "  ./bin/dev/startup.sh"
                exit 1
            fi
            ;;
        test)
            if ! curl -s http://localhost:4002 > /dev/null 2>&1; then
                print_status "❌ Test environment not running" $RED
                echo "Please start test environment first:"
                echo "  ./bin/test/startup.sh"
                exit 1
            fi
            ;;
        prod)
            if ! curl -s http://localhost:4004 > /dev/null 2>&1 && ! curl -s https://localhost:4005 > /dev/null 2>&1; then
                print_status "❌ Production environment not running" $RED
                echo "Please start production environment first:"
                echo "  ./bin/prod/startup.sh"
                exit 1
            fi
            ;;
    esac
}

check_environment_running

# Get password if not provided
if [ -z "$PASSWORD" ]; then
    echo ""
    print_status "Enter master password (will be hidden):" $BLUE
    read -s PASSWORD
    echo ""
    
    if [ -z "$PASSWORD" ]; then
        print_status "❌ Password cannot be empty" $RED
        exit 1
    fi
    
    # Confirm password
    print_status "Confirm master password:" $BLUE
    read -s PASSWORD_CONFIRM
    echo ""
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        print_status "❌ Passwords do not match" $RED
        exit 1
    fi
fi

# Validate password strength
if [ ${#PASSWORD} -lt 8 ]; then
    print_status "❌ Password must be at least 8 characters long" $RED
    exit 1
fi

# Setup master password using Mix task
print_status "🔐 Setting up master password..." $YELLOW

# Ensure Docker secrets are initialized for this environment
check_swarm_secrets "$ENVIRONMENT"

exec_in_stack_service "$ENVIRONMENT" mix run --no-compile -e "
# Start required applications
Application.ensure_all_started(:alerts)

case Alerts.Business.MasterPassword.setup_master_password(\"$PASSWORD\") do
  {:ok, _record} -> 
    IO.puts(\"✅ Master password configured successfully!\")
  {:error, changeset} -> 
    IO.puts(\"❌ Failed to configure master password:\")
    IO.inspect(changeset.errors)
    System.halt(1)
end
" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    print_status "✅ Master password configured successfully!" $GREEN
    echo ""
    print_status "🔒 Security Notes:" $YELLOW
    echo "  • Master password is SHA-256 hashed and AES-256-GCM encrypted"
    echo "  • Session timeout: 10 minutes (configurable with SESSION_TIMEOUT_MINUTES)"
    echo "  • All routes now require authentication"
    echo ""
    print_status "🚀 Restart your application to enable login screen:" $BLUE
    case $ENVIRONMENT in
        dev) echo "  ./bin/dev/startup.sh" ;;
        test) echo "  ./bin/test/startup.sh" ;;
        prod) echo "  ./bin/prod/startup.sh" ;;
    esac
else
    print_status "❌ Failed to configure master password" $RED
    exit 1
fi
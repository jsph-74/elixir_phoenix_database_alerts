#!/bin/bash
set -e

# Source shared functions
source "$(dirname "$0")/../helpers/functions.sh"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/run_backend_tests.sh"
BACKEND_SUCCESS=$?

"$SCRIPT_DIR/run_e2e_tests.sh"
E2E_SUCCESS=$?

if [ $BACKEND_SUCCESS -eq 0 ] && [ $E2E_SUCCESS -eq 0 ]; then
    print_status "🎉 All tests passed!" $GREEN
else
    print_status "❌ Some tests failed!" $RED
    exit 1
fi
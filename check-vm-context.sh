#!/bin/bash

# Expected hostname for the VM
EXPECTED_HOSTNAME="nas-test"

# Get current hostname
CURRENT_HOSTNAME=$(hostname)

# Check if hostname matches
if [ "$CURRENT_HOSTNAME" != "$EXPECTED_HOSTNAME" ]; then
    echo "----------------------------------------------------------------"
    echo "CRITICAL WARNING: WRONG EXECUTION CONTEXT DETECTED"
    echo "----------------------------------------------------------------"
    echo "You are trying to run this script on: '$CURRENT_HOSTNAME'"
    echo "This script is intended to run ONLY inside the VM: '$EXPECTED_HOSTNAME'"
    echo ""
    echo "Running this on your host machine could DESTROY your local Docker containers!"
    echo ""
    read -p "Are you ABSOLUTELY SURE you want to proceed? (Type 'yes' to continue): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborting execution."
        exit 1
    fi
    echo "Proceeding with caution..."
fi

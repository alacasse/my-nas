#!/bin/bash
set -e

# scripts/restart-dev.sh
# Restarts a deployment in the dev cluster by name matching.
# 
# Usage: ./scripts/restart-dev.sh <service-name-substring>

VM_NAME="nas-test"
SEARCH_TERM="$1"

if [ -z "$SEARCH_TERM" ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 qbittorrent"
    exit 1
fi

echo "Searching for deployments matching '$SEARCH_TERM'..."

# Get all deployments in all namespaces
# Output format: NAMESPACE/DEPLOYMENT_NAME
# We use awk to parse generic table output to avoid quoting issues with jsonpath through multipass
DEPLOYMENTS=$(multipass exec "$VM_NAME" -- sudo k3s kubectl get deployments -A --no-headers | awk '{print $1 "/" $2}')

# Filter lines matching the search term
MATCHES=$(echo "$DEPLOYMENTS" | grep -i "$SEARCH_TERM" || true)

COUNT=$(echo "$MATCHES" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
    echo "❌ No deployments found matching '$SEARCH_TERM'."
    exit 1
elif [ "$COUNT" -gt 1 ]; then
    echo "⚠️  Multiple matches found:"
    echo "$MATCHES"
    echo ""
    echo "Please be more specific."
    exit 1
fi

# Exactly one match found
IFS='/' read -r NAMESPACE DEPLOYMENT <<< "$MATCHES"

echo "✅ Found deployment: $NAMESPACE/$DEPLOYMENT"
echo "Restarting..."

multipass exec "$VM_NAME" -- sudo k3s kubectl rollout restart deployment "$DEPLOYMENT" -n "$NAMESPACE"

echo "🚀 Restart triggered for $DEPLOYMENT in namespace $NAMESPACE."

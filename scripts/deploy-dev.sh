#!/bin/bash
set -e

# deploy-dev.sh - Fast development deployment script
# Uses the shared mount in the VM - no file syncing needed!
#
# Usage: ./scripts/deploy-dev.sh [--watch]

VM_NAME="nas-test"
REMOTE_PATH="/home/ubuntu/my-nas"

echo "=== Deploying to Development Cluster ==="

# Check if VM exists and K3S is running
if ! multipass exec "$VM_NAME" -- sudo k3s kubectl get nodes &>/dev/null; then
    echo "ERROR: K3S is not running in VM '$VM_NAME'"
    echo "Run: ./scripts/k3s-dev-setup.sh first"
    exit 1
fi

# Apply manifests directly from shared mount
echo ""
echo "Applying manifests from $REMOTE_PATH/clusters/dev/..."
multipass exec "$VM_NAME" -- sudo k3s kubectl apply -k "${REMOTE_PATH}/clusters/dev/" || {
    echo ""
    echo "Note: Some resources may have failed. This is often normal on first deploy."
    echo "Re-run this script to retry."
}

# Show status
echo ""
echo "Current pods:"
multipass exec "$VM_NAME" -- sudo k3s kubectl get pods -A

# Optional: Watch pods
if [ "$1" = "--watch" ]; then
    echo ""
    echo "Watching pods (Ctrl+C to stop)..."
    multipass exec "$VM_NAME" -- sudo k3s kubectl get pods -A -w
fi

echo ""
echo "=== Deploy Complete ==="

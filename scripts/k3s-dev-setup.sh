#!/bin/bash
set -e

# k3s-dev-setup.sh - One-time development environment setup
# Sets up K3S in the Multipass VM and configures local kubectl access
#
# Usage: ./scripts/k3s-dev-setup.sh

VM_NAME="nas-test"

echo "=== K3S Development Environment Setup ==="

# Check if VM exists
if ! multipass info "$VM_NAME" &>/dev/null; then
    echo "ERROR: Multipass VM '$VM_NAME' not found."
    echo "Create it first with: multipass launch --name $VM_NAME"
    exit 1
fi

# Ensure project is mounted
echo "Configuring mount..."
multipass mount . "$VM_NAME:/home/ubuntu/my-nas" || true

# Ensure volumes are mounted
echo "Configuring volumes..."
multipass mount "./nas-volumes" "$VM_NAME:/home/ubuntu/nas-volumes" || true

# 1. Install K3S in Multipass VM
echo ""
echo "Step 1: Installing K3S in VM..."
multipass exec "$VM_NAME" -- bash -c 'curl -sfL https://get.k3s.io | sh -'

# 2. Wait for K3S to be ready
echo ""
echo "Step 2: Waiting for K3S to be ready..."
echo "  (K3S needs a moment to register the node...)"
sleep 10  # Give K3S time to start and register the node

# Retry loop for node readiness
MAX_RETRIES=12
RETRY_COUNT=0
until multipass exec "$VM_NAME" -- sudo k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: K3S node not ready after 2 minutes"
        exit 1
    fi
    echo "  Waiting for node to be ready... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done
echo "✓ K3S node is ready"

# 3. Get VM IP address (first IPv4 is the main one)
VM_IP=$(multipass info "$VM_NAME" | grep IPv4 | head -1 | awk '{print $2}')
echo "VM IP: $VM_IP"

# 4. Setup kubeconfig for local access
echo ""
echo "Step 3: Setting up kubeconfig..."
mkdir -p ~/.kube

# Create a separate kubeconfig file with proper naming
KUBECONFIG_FILE="$HOME/.kube/nas-test-config"
multipass exec "$VM_NAME" -- sudo cat /etc/rancher/k3s/k3s.yaml | \
    sed "s/127.0.0.1/$VM_IP/g" | \
    sed "s/default/nas-test/g" > "$KUBECONFIG_FILE"

echo "Kubeconfig saved to $KUBECONFIG_FILE"

# Optionally merge into main kubeconfig
if [ -f "$HOME/.kube/config" ]; then
    echo "Merging into main kubeconfig..."
    # Backup existing config
    cp "$HOME/.kube/config" "$HOME/.kube/config.backup.$(date +%Y%m%d%H%M%S)"
    # Merge configs
    KUBECONFIG="$HOME/.kube/config:$KUBECONFIG_FILE" kubectl config view --flatten > "$HOME/.kube/config.merged"
    mv "$HOME/.kube/config.merged" "$HOME/.kube/config"
    echo "✓ Merged into ~/.kube/config"
    echo "  Use: kubectl config use-context nas-test"
else
    # No existing config, just use our file
    cp "$KUBECONFIG_FILE" "$HOME/.kube/config"
    echo "✓ Created ~/.kube/config"
fi

# Set the context
kubectl config use-context nas-test 2>/dev/null || true

# 5. Install Flux CLI in VM (local-only mode)
echo ""
echo "Step 4: Installing Flux in VM..."
multipass exec "$VM_NAME" -- bash -c 'curl -s https://fluxcd.io/install.sh | sudo bash'
multipass exec "$VM_NAME" -- sudo k3s kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

# 6. Verify setup
echo ""
echo "Step 5: Verifying setup..."
kubectl get nodes
echo ""
multipass exec "$VM_NAME" -- sudo k3s kubectl get pods -n flux-system

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Your kubectl is now configured to use the nas-test cluster."
echo "Run: kubectl get nodes"
echo ""
echo "To switch contexts later:"
echo "  kubectl config use-context nas-test"
echo ""
echo "To deploy manifests:"
echo "  ./scripts/deploy-dev.sh"

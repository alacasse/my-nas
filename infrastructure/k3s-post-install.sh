#!/bin/bash
set -e

# k3s-post-install.sh - Post-installation script for K3S cluster setup
# Run this after OS installation completes
#
# Usage:
#   ./k3s-post-install.sh dev   # Development mode (local Flux, no Git)
#   ./k3s-post-install.sh prod  # Production mode (GitHub integration)

MODE="${1:-prod}"
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_REPO="${GITHUB_REPO:-my-nas}"

echo "=== K3S Post-Installation Setup ==="
echo "Mode: $MODE"

# 1. Verify K3S is running
echo ""
echo "Step 1: Verifying K3S installation..."
if ! sudo k3s kubectl get nodes &>/dev/null; then
    echo "ERROR: K3S is not running. Please check installation."
    exit 1
fi
sudo k3s kubectl get nodes
echo "✓ K3S is running"

# 2. Wait for all nodes to be ready
echo ""
echo "Step 2: Waiting for nodes to be ready..."
sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=120s
echo "✓ All nodes ready"

# 3. Install Flux CLI
echo ""
echo "Step 3: Installing Flux CLI..."
if ! command -v flux &> /dev/null; then
    curl -s https://fluxcd.io/install.sh | sudo bash
fi
flux --version
echo "✓ Flux CLI installed"

# 4. Bootstrap Flux based on mode
echo ""
echo "Step 4: Bootstrapping Flux..."
if [ "$MODE" = "prod" ]; then
    # Production: Full GitHub integration
    if [ -z "$GITHUB_USER" ]; then
        echo "ERROR: GITHUB_USER environment variable is required for prod mode"
        echo "Usage: GITHUB_USER=yourusername ./k3s-post-install.sh prod"
        exit 1
    fi
    echo "Bootstrapping Flux with GitHub integration..."
    flux bootstrap github \
        --owner="$GITHUB_USER" \
        --repository="$GITHUB_REPO" \
        --branch=main \
        --path=clusters/prod \
        --personal
    
    # Patch the Flux Kustomization to enable SOPS decryption
    echo "Enabling SOPS decryption on flux-system..."
    sudo k3s kubectl patch kustomization flux-system \
        --namespace flux-system \
        --type=merge \
        --patch '{"spec": {"decryption": {"provider": "sops", "secretRef": {"name": "sops-age"}}}}'
    echo "✓ Enabled SOPS decryption"else
    # Development: Local-only installation (no Git required)
    echo "Installing Flux in local-only mode (no Git integration)..."
    flux install
    echo ""
    echo "NOTE: In dev mode, use 'kubectl apply -k clusters/dev/' to deploy manifests."
    echo "      Or use the deploy-dev.sh script for automated deployment."
fi

# 4b. Configure SOPS Decryption Key
echo ""
echo "Step 4b: Configuring SOPS decryption key..."
if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
    echo "Found Age key at $HOME/.config/sops/age/keys.txt"
    # Ensure namespace exists (it should from flux install/bootstrap)
    sudo k3s kubectl create namespace flux-system --dry-run=client -o yaml | sudo k3s kubectl apply -f -
    
    # Create the secret
    sudo k3s kubectl create secret generic sops-age \
        --namespace=flux-system \
        --from-file=age.agekey="$HOME/.config/sops/age/keys.txt" \
        --dry-run=client -o yaml | sudo k3s kubectl apply -f -
    echo "✓ Created 'sops-age' secret in flux-system"
else
    echo "WARNING: No Age key found at $HOME/.config/sops/age/keys.txt"
    echo "Secrets decryption will fail until you create the 'sops-age' secret manually."
fi
# 5. Verify Flux installation
echo ""
echo "Step 5: Verifying Flux installation..."
flux check
echo "✓ Flux bootstrap complete"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
if [ "$MODE" = "prod" ]; then
    echo "  - Flux is now watching your GitHub repository"
    echo "  - Commit changes to clusters/prod/ and push to deploy"
else
    echo "  - Run: kubectl apply -k clusters/dev/"
    echo "  - Or use: ./scripts/deploy-dev.sh"
fi

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
else
    # Development: Local-only installation (no Git required)
    echo "Installing Flux in local-only mode (no Git integration)..."
    flux install
    echo ""
    echo "NOTE: In dev mode, use 'kubectl apply -k clusters/dev/' to deploy manifests."
    echo "      Or use the deploy-dev.sh script for automated deployment."
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

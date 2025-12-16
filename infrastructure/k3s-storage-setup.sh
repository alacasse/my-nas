#!/usr/bin/env bash
set -euo pipefail

# k3s-storage-setup.sh
#
# Installs the democratic-csi chart and configures a ZFS-backed
# StorageClass (`zfs-nfs`) on the NAS k3s cluster.
#
# This script is intended to be run on the NAS host AFTER:
#   - OS install + ZFS pool import (see docs/os-rebuild.md)
#   - k3s install and bootstrap (see infrastructure/k3s-post-install.sh)
#
# Usage (on NAS, as root):
#   cd /path/to/my-nas
#   sudo ./infrastructure/k3s-storage-setup.sh
#
# It assumes:
#   - ZFS pool is named "nas" and mounted at /mnt/storage
#   - k3s kubeconfig is at /etc/rancher/k3s/k3s.yaml

KUBECONFIG_PATH="${KUBECONFIG_PATH:-/etc/rancher/k3s/k3s.yaml}"
VALUES_FILE="${VALUES_FILE:-$(dirname "$0")/democratic-csi/values-zfs-nfs.yaml}"
NAMESPACE="${NAMESPACE:-democratic-csi}"
RELEASE_NAME="${RELEASE_NAME:-democratic-csi}"

echo "=== k3s Storage Setup (democratic-csi) ==="
echo "KUBECONFIG : ${KUBECONFIG_PATH}"
echo "Values file: ${VALUES_FILE}"
echo "Namespace  : ${NAMESPACE}"
echo "Release    : ${RELEASE_NAME}"
echo

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)." >&2
  exit 1
fi

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "ERROR: k3s kubeconfig not found at ${KUBECONFIG_PATH}." >&2
  echo "Ensure k3s is installed and the path is correct." >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo "Step 1: Ensuring Helm is installed..."
if ! command -v helm >/dev/null 2>&1; then
  echo "  - Helm not found, installing..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "  - Helm already installed."
fi

echo
echo "Step 2: Adding democratic-csi Helm repo..."
helm repo add democratic-csi https://democratic-csi.github.io/charts/ >/dev/null 2>&1 || true
helm repo update democratic-csi

echo
echo "Step 3: Verifying values file..."
if [[ ! -f "$VALUES_FILE" ]]; then
  echo "ERROR: Values file not found at ${VALUES_FILE}." >&2
  echo "Create it (e.g., copy and adjust infrastructure/democratic-csi/values-zfs-nfs.yaml)." >&2
  exit 1
fi

echo
echo "Step 4: Installing/upgrading democratic-csi chart..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "${RELEASE_NAME}" democratic-csi/democratic-csi \
  --namespace "${NAMESPACE}" \
  -f "${VALUES_FILE}"

echo
echo "Step 5: Waiting for democratic-csi pods to be ready..."
kubectl -n "${NAMESPACE}" get pods
kubectl -n "${NAMESPACE}" wait --for=condition=Ready pods --all --timeout=300s

echo
echo "Step 6: Verifying StorageClass 'zfs-nfs'..."
kubectl get storageclass zfs-nfs || {
  echo "WARNING: StorageClass 'zfs-nfs' not found."
  echo "Check the democratic-csi values file to ensure it defines a StorageClass named 'zfs-nfs'."
}

echo
echo "=== Storage setup complete (democratic-csi) ==="
echo "PVCs with storageClassName=zfs-nfs should now be dynamically provisioned on pool 'nas'."


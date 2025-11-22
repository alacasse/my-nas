#!/bin/bash
set -e

# Check execution context
./check-vm-context.sh || exit 1

# Define network
NETWORK_NAME="lan_net"
SUBNET="172.19.0.0/24"

# Storage base for bind mounts (defaults to env file value or ~/nas-volumes)
ENV_FILE="./docker/.env.dev"
STORAGE_BASE_VAL="${STORAGE_BASE:-}"
if [ -z "$STORAGE_BASE_VAL" ] && [ -f "$ENV_FILE" ]; then
  STORAGE_BASE_VAL="$(grep -E '^STORAGE_BASE=' "$ENV_FILE" | head -n1 | cut -d= -f2- || true)"
fi
if [ -z "$STORAGE_BASE_VAL" ]; then
  STORAGE_BASE_VAL="$HOME/nas-volumes"
fi

# Create Docker network if not exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network $NETWORK_NAME..."
  docker network create --subnet=$SUBNET $NETWORK_NAME
else
  echo "Docker network $NETWORK_NAME already exists."
fi

# Ensure storage directories exist for qbittorrent binds
mkdir -p "${STORAGE_BASE_VAL}/qbittorrent/appdata" "${STORAGE_BASE_VAL}/nas/downloads"

# Start qBittorrent VPN container
echo "Starting qBittorrent VPN container..."
# Clean up any stale torrent container
docker rm -f torrent >/dev/null 2>&1 || true
docker rm -f qbittorrentvpn >/dev/null 2>&1 || true

docker compose --env-file ./docker/.env.dev -f ./docker/torrent/docker-compose.yml up -d --build

echo "qBittorrent VPN container started."

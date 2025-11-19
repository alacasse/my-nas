#!/bin/bash
set -e

# Define network
NETWORK_NAME="vpn_net"
SUBNET="172.18.0.0/24"

# Storage base for bind mounts (defaults to env file value or ~/nas-volumes)
ENV_FILE="./docker/.env.dev"
STORAGE_BASE_VAL="${STORAGE_BASE:-}"
if [ -z "$STORAGE_BASE_VAL" ] && [ -f "$ENV_FILE" ]; then
  STORAGE_BASE_VAL="$(grep -E '^STORAGE_BASE=' "$ENV_FILE" | head -n1 | cut -d= -f2- || true)"
fi
if [ -z "$STORAGE_BASE_VAL" ]; then
  STORAGE_BASE_VAL="$HOME/nas-volumes"
fi

LAN_NETWORK_NAME="${LAN_NETWORK_NAME:-lan_net}"
LAN_SUBNET="${LAN_SUBNET:-172.19.0.0/24}"

# Create Docker network if not exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network $NETWORK_NAME..."
  docker network create --subnet=$SUBNET $NETWORK_NAME
else
  echo "Docker network $NETWORK_NAME already exists."
fi

# Ensure LAN network exists (needed by torrent compose)
if ! docker network ls | grep -q "$LAN_NETWORK_NAME"; then
  echo "Creating Docker network $LAN_NETWORK_NAME..."
  docker network create --subnet=$LAN_SUBNET $LAN_NETWORK_NAME
else
  echo "Docker network $LAN_NETWORK_NAME already exists."
fi

# Ensure storage directories exist for qbittorrent binds
mkdir -p "${STORAGE_BASE_VAL}/qbittorrent/appdata" "${STORAGE_BASE_VAL}/nas/downloads"

# Start VPN container
echo "Starting VPN container..."
docker compose --env-file ./docker/.env.dev -f ./docker/vpn/docker-compose.yml up -d --build

# Wait for VPN container to be up
echo "Waiting 5 seconds for VPN container to stabilize..."
sleep 5

# Start torrent container
echo "Starting Torrent container..."
# Clean up any stale torrent container/endpoints first
docker network disconnect -f "$LAN_NETWORK_NAME" torrent >/dev/null 2>&1 || true
docker network disconnect -f "$NETWORK_NAME" torrent >/dev/null 2>&1 || true
docker rm -f torrent >/dev/null 2>&1 || true
docker compose --env-file ./docker/.env.dev -f ./docker/torrent/docker-compose.yml down >/dev/null 2>&1 || true
docker compose --env-file ./docker/.env.dev -f ./docker/torrent/docker-compose.yml up -d --build

echo "All services started. Torrent container is routed through VPN."

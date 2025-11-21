#!/bin/bash
set -e

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

# Check Docker version first
./check-docker-version.sh
if [ $? -ne 0 ]; then
    exit 1
fi

# Create necessary directoriesy
mkdir -p "${STORAGE_BASE_VAL}/nas"

# Create Docker network if not exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network $NETWORK_NAME..."
  docker network create --subnet=$SUBNET $NETWORK_NAME
else
  echo "Docker network $NETWORK_NAME already exists."
fi

# Start NAS stack
echo "Starting NAS stack (Samba, Filebrowser)..."
docker compose --env-file ./docker/.env.dev -f ./docker/nas/docker-compose.yml up -d --build

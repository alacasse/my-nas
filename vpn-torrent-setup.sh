#!/bin/bash
set -e

# Define network
NETWORK_NAME="vpn_net"
SUBNET="172.18.0.0/24"

# Create Docker network if not exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network $NETWORK_NAME..."
  docker network create --subnet=$SUBNET $NETWORK_NAME
else
  echo "Docker network $NETWORK_NAME already exists."
fi

# Start VPN container
echo "Starting VPN container..."
docker compose --env-file ./docker/.env.dev -f ./docker/vpn/docker-compose.yml up -d --build

# Wait for VPN container to be up
echo "Waiting 5 seconds for VPN container to stabilize..."
sleep 5

# Start torrent container
echo "Starting Torrent container..."
docker compose --env-file ./docker/.env.dev -f ./docker/torrent/docker-compose.yml up -d --build

echo "All services started. Torrent container is routed through VPN."

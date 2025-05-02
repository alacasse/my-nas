#!/bin/bash

# Define names and paths
VPN_COMPOSE_FILE="./docker/vpn/docker-compose.yml"
TORRENT_COMPOSE_FILE="./docker/torrent/docker-compose.yml"
CUSTOM_NETWORK="vpn_net"  # Match what was created in setup

echo "Stopping Torrent container..."
docker compose -f "$TORRENT_COMPOSE_FILE" down

echo "Stopping VPN container..."
docker compose -f "$VPN_COMPOSE_FILE" down

echo "Removing custom Docker network if exists..."
docker network inspect "$CUSTOM_NETWORK" &>/dev/null && docker network rm "$CUSTOM_NETWORK"

echo "Teardown complete."
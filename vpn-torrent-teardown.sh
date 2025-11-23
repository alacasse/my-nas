#!/bin/bash

# Define names and paths
TORRENT_COMPOSE_FILE="./docker/torrent/docker-compose.yml"
CUSTOM_NETWORK="lan_net"  # Match what was created in setup

echo "Stopping Torrent container..."
docker compose --env-file ./docker/.env.dev -f "$TORRENT_COMPOSE_FILE" down



echo "Removing custom Docker network if exists..."
docker network inspect "$CUSTOM_NETWORK" &>/dev/null && docker network rm "$CUSTOM_NETWORK"

echo "Teardown complete."
#!/bin/bash

# Define names and paths
TORRENT_COMPOSE_FILE="./docker/torrent/docker-compose.yml"
CUSTOM_NETWORK="lan_net"  # Match what was created in setup

echo "Stopping Torrent container..."
docker compose --env-file ./docker/.env.dev -f "$TORRENT_COMPOSE_FILE" down

# Network is shared, do not remove it.
echo "Teardown complete."
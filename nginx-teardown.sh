#!/bin/bash

# Define names and paths
NGINX_COMPOSE_FILE="./docker/nginx/docker-compose.yml"
CUSTOM_NETWORK="lan_net"  # Match what was created in setup

echo "Stopping nginx container..."
docker compose --env-file ./docker/.env.dev -f "$NGINX_COMPOSE_FILE" down

echo "Removing custom Docker network if exists..."
docker network inspect "$CUSTOM_NETWORK" &>/dev/null && docker network rm "$CUSTOM_NETWORK"

echo "Teardown complete."
#!/bin/bash
set -e

# Define network
NETWORK_NAME="lan_net"
SUBNET="172.19.0.0/24"

# Create Docker network if not exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network $NETWORK_NAME..."
  docker network create --subnet=$SUBNET $NETWORK_NAME
else
  echo "Docker network $NETWORK_NAME already exists."
fi

# Start nginx container
echo "Starting NGINX container..."
# docker compose --env-file ./docker/.env.dev -f ./docker/nginx/docker-compose.yml up -d --build
docker compose -f ./docker/nginx/docker-compose.yml up -d --build
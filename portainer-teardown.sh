#!/bin/bash

echo "Stopping Portainer..."
docker compose --env-file ./docker/.env.dev -f ./docker/portainer/docker-compose.yml down

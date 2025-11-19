#!/bin/bash

echo "Stopping NAS stack..."
docker compose --env-file ./docker/.env.dev -f ./docker/nas/docker-compose.yml down

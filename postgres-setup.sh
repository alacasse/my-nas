#!/bin/bash
set -e

echo "Starting Postgres..."
docker compose --env-file ./docker/.env.dev -f ./docker/postgres/docker-compose.yml up -d --build

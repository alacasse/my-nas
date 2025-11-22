#!/bin/bash
set -e

# Load env
ENV_FILE="./docker/.env.dev"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

CONTAINER_NAME="qbittorrentvpn"
CONFIG_PATH="/config/qBittorrent/config/qBittorrent.conf"

echo "Checking if container $CONTAINER_NAME is running..."
if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "Container $CONTAINER_NAME is not running. Starting it..."
  docker start "$CONTAINER_NAME"
  sleep 5
fi

echo "Configuring qBittorrent to bypass auth for LAN (using docker exec)..."

# Helper function to run sed inside container
docker_sed() {
  docker exec "$CONTAINER_NAME" sed -i "$1" "$CONFIG_PATH"
}

# Remove existing password and username lines
docker_sed '/WebUI\\Password_PBKDF2/d'
docker_sed '/WebUI\\Username/d'

# Remove existing whitelist lines to avoid duplicates
docker_sed '/WebUI\\AuthSubnetWhitelist/d'
docker_sed '/WebUI\\TrustedProxies/d'

# Add whitelist configuration under [Preferences]
# Whitelist: LAN (192.168.50.0/24), Docker (172.19.0.0/24), Localhost
docker_sed "/\[Preferences\]/a WebUI\\\\AuthSubnetWhitelist=192.168.50.0/24,172.19.0.0/24,127.0.0.1/32"
docker_sed "/\[Preferences\]/a WebUI\\\\AuthSubnetWhitelistEnabled=true"
docker_sed "/\[Preferences\]/a WebUI\\\\LocalHostAuth=false"
# Trust Nginx proxy (Docker subnet)
docker_sed "/\[Preferences\]/a WebUI\\\\TrustedProxies=172.19.0.0/24"

echo "Restarting qBittorrent VPN container to apply changes..."
docker restart "$CONTAINER_NAME"

echo "qBittorrent password set to: $PASS"

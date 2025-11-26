#!/bin/bash
set -e

# Ensure we are in the script's directory
cd "$(dirname "$0")"

# Check execution context
./check-vm-context.sh || exit 1

# Define network
NETWORK_NAME="lan_net"
SUBNET="172.19.0.0/24"

# Storage base for bind mounts (defaults to env file value or ~/nas-volumes)
ENV_FILE="./docker/.env.dev"

# Load environment variables from file if it exists
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment variables from $ENV_FILE..."
  set -a
  source "$ENV_FILE"
  set +a
fi

STORAGE_BASE_VAL="${STORAGE_BASE:-}"
if [ -z "$STORAGE_BASE_VAL" ]; then
  STORAGE_BASE_VAL="$HOME/nas-volumes"
fi

# Validate essential variables
if [ -z "${VPN_USER:-}" ]; then
  echo "ERROR: VPN_USER is not set. Please set it in $ENV_FILE or export it."
  exit 1
fi

if [ -z "${VPN_PASS:-}" ]; then
  echo "ERROR: VPN_PASS is not set. Please set it in $ENV_FILE or export it."
  exit 1
fi

if [ -z "${LAN_NETWORK:-}" ] || [[ "$LAN_NETWORK" == *"*"* ]]; then
  echo "ERROR: LAN_NETWORK is missing or invalid (contains wildcards). Please set a valid CIDR (e.g., 192.168.50.0/24) in $ENV_FILE."
  exit 1
fi

# Create Docker network if not exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network $NETWORK_NAME..."
  docker network create --subnet=$SUBNET $NETWORK_NAME
else
  echo "Docker network $NETWORK_NAME already exists."
fi

# Ensure storage directories exist for qbittorrent binds
mkdir -p "${STORAGE_BASE_VAL}/qbittorrent/appdata/qBittorrent/config"
mkdir -p "${STORAGE_BASE_VAL}/nas/downloads"

# Copy qBittorrent config (only if it doesn't exist)
CONFIG_PATH="${STORAGE_BASE_VAL}/qbittorrent/appdata/qBittorrent/config/qBittorrent.conf"
if [ ! -f "$CONFIG_PATH" ]; then
  echo "Copying default qBittorrent config..."
  cp ./docker/torrent/qBittorrent.conf "$CONFIG_PATH"
else
  echo "qBittorrent config already exists. Skipping copy."
fi

# Set WebUI Password
PASS_VAL="${QBIT_WEBUI_PASS:-adminadmin}"
echo "Setting qBittorrent WebUI password..."
if command -v python3 &> /dev/null; then
  HASH=$(python3 ./docker/torrent/gen-qbittorrent-pass.py "$PASS_VAL")
  # Use sed to replace the password line. We use | as delimiter to avoid issues with / in base64
  # We need to escape the backslash in the key name for sed
  sed -i "s|WebUI\\\\Password_PBKDF2=.*|WebUI\\\\Password_PBKDF2=\"${HASH}\"|" "${STORAGE_BASE_VAL}/qbittorrent/appdata/qBittorrent/config/qBittorrent.conf"
else
  echo "WARNING: python3 not found. Skipping password update. Default password in config will be used."
fi

# Start qBittorrent VPN container
echo "Starting qBittorrent VPN container..."
# Clean up any stale torrent container
docker rm -f torrent >/dev/null 2>&1 || true
docker rm -f qbittorrentvpn >/dev/null 2>&1 || true

docker compose --env-file ./docker/.env.dev -f ./docker/torrent/docker-compose.yml up -d --build

echo "qBittorrent VPN container started."

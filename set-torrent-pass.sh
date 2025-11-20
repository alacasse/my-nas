#!/bin/bash
set -e

# Load env
ENV_FILE="./docker/.env.dev"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

PASS="${NAS_PASSWORD:-password}"
CONF_FILE="$HOME/nas-volumes/qbittorrent/appdata/qBittorrent/qBittorrent.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "Config file not found at $CONF_FILE. Is qBittorrent running?"
  exit 1
fi

echo "Generating hash for password..."
# Generate PBKDF2-HMAC-SHA512 hash (qBittorrent 4.2+ format)
HASH=$(python3 -c "
import base64, hashlib, os
password = '$PASS'
salt = os.urandom(16)
iterations = 100000
dk = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, iterations)
print(f'@ByteArray({base64.b64encode(salt + dk).decode()})')
")

echo "Updating config file..."
# Remove existing password line if present
sed -i '/WebUI\\Password_PBKDF2/d' "$CONF_FILE"
# Add new password line under [Preferences]
sed -i "/\[Preferences\]/a WebUI\\\\Password_PBKDF2=$HASH" "$CONF_FILE"
# Ensure username is admin
sed -i '/WebUI\\Username/d' "$CONF_FILE"
sed -i "/\[Preferences\]/a WebUI\\\\Username=admin" "$CONF_FILE"

echo "Restarting torrent container..."
docker stop torrent
docker network disconnect -f lan_net torrent || true
docker network disconnect -f vpn_net torrent || true
docker start torrent

echo "qBittorrent password set to: $PASS"

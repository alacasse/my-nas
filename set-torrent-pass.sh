#!/bin/bash
set -e

# Load env
ENV_FILE="./docker/.env.dev"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

PASS="${NAS_PASSWORD:-password}"
CONF_FILE="$HOME/nas-volumes/qbittorrent/appdata/qBittorrent/config/qBittorrent.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "Config file not found at $CONF_FILE. Is qBittorrent running?"
  exit 1
fi

echo "Configuring qBittorrent to bypass auth for LAN..."
# Stop container first to prevent overwrite
docker stop qbittorrentvpn

# Remove existing password and username lines
sed -i '/WebUI\\Password_PBKDF2/d' "$CONF_FILE"
sed -i '/WebUI\\Username/d' "$CONF_FILE"

# Remove existing whitelist lines to avoid duplicates
sed -i '/WebUI\\AuthSubnetWhitelist/d' "$CONF_FILE"
sed -i '/WebUI\\TrustedProxies/d' "$CONF_FILE"

# Add whitelist configuration under [Preferences]
# Whitelist: LAN (192.168.50.0/24), Docker (172.19.0.0/24), Localhost
sed -i "/\[Preferences\]/a WebUI\\\\AuthSubnetWhitelist=192.168.50.0/24,172.19.0.0/24,127.0.0.1/32" "$CONF_FILE"
sed -i "/\[Preferences\]/a WebUI\\\\AuthSubnetWhitelistEnabled=true" "$CONF_FILE"
sed -i "/\[Preferences\]/a WebUI\\\\LocalHostAuth=false" "$CONF_FILE"
# Trust Nginx proxy (Docker subnet)
sed -i "/\[Preferences\]/a WebUI\\\\TrustedProxies=172.19.0.0/24" "$CONF_FILE"

echo "Restarting qBittorrent VPN container..."
docker start qbittorrentvpn

echo "qBittorrent password set to: $PASS"

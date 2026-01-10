#!/bin/bash
set -e

echo "=== qBittorrent Storage Initialization ==="

CONF_DIR="/config/qBittorrent/config"
DEFAULTS_DIR="/defaults"

# Ensure directory structure for config and logs inside the config PVC
mkdir -p "$CONF_DIR"
mkdir -p "/config/qBittorrent/logs"

# Function to copy defaults only if missing
copy_if_needed() {
  local src="$1"
  local dest="$2"
  local name
  name="$(basename "$src")"
  if [ ! -f "$dest" ]; then
    echo "Copying $name (file missing)..."
    cp "$src" "$dest"
  fi
}

copy_if_needed "$DEFAULTS_DIR/qBittorrent.conf" "$CONF_DIR/qBittorrent.conf"

# Render categories with configurable media root
QBIT_MEDIA_ROOT="${QBIT_MEDIA_ROOT:-/data}"
if [ ! -f "$CONF_DIR/categories.json" ]; then
  echo "Rendering categories.json with media root: $QBIT_MEDIA_ROOT"
  sed "s#__QBIT_MEDIA_ROOT__#${QBIT_MEDIA_ROOT}#g" "$DEFAULTS_DIR/categories.json" > "$CONF_DIR/categories.json"
fi

# Copy watched_folders template if missing (no templating needed for now)
copy_if_needed "$DEFAULTS_DIR/watched_folders.json" "$CONF_DIR/watched_folders.json"

# Ensure data directories exist (backed by PVC)
mkdir -p /data/downloads
mkdir -p /data/torrents
mkdir -p /data/movies
mkdir -p /data/music
mkdir -p /data/tv
mkdir -p /data/games
mkdir -p /data/books

echo "=== Config initialization complete ==="

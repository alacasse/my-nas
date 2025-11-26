#!/bin/bash
set -e

# sync-configs.sh - Synchronize configuration files between source and persistent storage
# Usage:
#   ./sync-configs.sh         # Sync all configs to STORAGE_BASE/configs/
#   ./sync-configs.sh check   # Check which mode is active

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ENV_FILE:-./docker/.env.dev}"

# Load environment
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "Error: Environment file $ENV_FILE not found"
  exit 1
fi

CONFIG_MODE="${CONFIG_MODE:-dev}"
STORAGE_BASE="${STORAGE_BASE:-}"

if [ -z "$STORAGE_BASE" ]; then
  echo "Error: STORAGE_BASE not set in $ENV_FILE"
  exit 1
fi

# Define config mappings (source -> destination under STORAGE_BASE/configs/)
declare -A CONFIGS=(
  ["docker/observability/grafana/provisioning"]="observability/grafana/provisioning"
  ["docker/observability/loki-config.yml"]="observability/loki-config.yml"
  ["docker/observability/promtail-config.yml"]="observability/promtail-config.yml"
  ["docker/observability/prometheus.yml"]="observability/prometheus.yml"
  ["docker/torrent/qBittorrent.conf"]="torrent/qBittorrent.conf"
  # Add more config paths as needed
)

case "${1:-sync}" in
  check)
    echo "Current configuration:"
    echo "  CONFIG_MODE: $CONFIG_MODE"
    echo "  STORAGE_BASE: $STORAGE_BASE"
    echo ""
    if [ "$CONFIG_MODE" = "dev" ]; then
      echo "Dev mode: Services bind mount directly from source"
      echo "  Grafana: ./docker/observability/grafana/provisioning"
    else
      echo "Prod mode: Services bind mount from persistent storage"
      echo "  Grafana: $STORAGE_BASE/configs/observability/grafana/provisioning"
    fi
    ;;

  sync)
    if [ "$CONFIG_MODE" = "dev" ]; then
      echo "Running in dev mode - no sync needed (configs mounted from source)"
      exit 0
    fi

    echo "Syncing configs to persistent storage at: $STORAGE_BASE/configs/"
    mkdir -p "$STORAGE_BASE/configs"

    for src in "${!CONFIGS[@]}"; do
      dest="${CONFIGS[$src]}"
      src_path="$SCRIPT_DIR/$src"
      dest_path="$STORAGE_BASE/configs/$dest"

      if [ ! -e "$src_path" ]; then
        echo "Warning: Source not found: $src_path"
        continue
      fi

      # Create destination directory
      dest_dir="$(dirname "$dest_path")"
      mkdir -p "$dest_dir"

      # Copy (preserve structure for directories)
      if [ -d "$src_path" ]; then
        echo "  Syncing directory: $src -> $dest"
        rsync -av --delete "$src_path/" "$dest_path/"
      else
        echo "  Syncing file: $src -> $dest"
        cp -f "$src_path" "$dest_path"
      fi
    done

    echo ""
    echo "✓ Config sync complete"
    echo "Run your docker compose commands with: --env-file ./docker/.env.prod"
    ;;

  *)
    echo "Usage: $0 [check|sync]"
    echo "  check - Display current config mode"
    echo "  sync  - Sync configs to persistent storage (for prod mode)"
    exit 1
    ;;
esac

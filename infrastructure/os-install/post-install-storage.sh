#!/usr/bin/env bash
set -euo pipefail

# post-install-storage.sh
#
# Post-install helper for the NAS OS:
# - Ensures ZFS tools are installed
# - Imports the existing ZFS pool (default: "nas")
# - Sets its mountpoint to /mnt/storage (configurable)
# - Creates basic directory layout for media and k3s apps
#
# Usage (on the NAS, as root):
#   sudo POOL_NAME=nas MOUNTPOINT=/mnt/storage ./infrastructure/os-install/post-install-storage.sh
#
# Environment variables:
#   POOL_NAME   - ZFS pool name (default: nas)
#   MOUNTPOINT  - Desired mountpoint for the pool (default: /mnt/storage)
#   PUID        - UID for app data ownership (default: 1000)
#   PGID        - GID for app data ownership (default: same as PUID)

POOL_NAME="${POOL_NAME:-nas}"
MOUNTPOINT="${MOUNTPOINT:-/mnt/storage}"
PUID="${PUID:-1000}"
PGID="${PGID:-$PUID}"

echo "=== NAS Post-Install Storage Setup ==="
echo "Pool name  : ${POOL_NAME}"
echo "Mountpoint : ${MOUNTPOINT}"
echo "PUID/PGID  : ${PUID}:${PGID}"
echo

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)." >&2
  exit 1
fi

echo "Step 1: Ensuring ZFS tools are installed..."
if ! command -v zpool >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y zfsutils-linux
else
  echo "  ZFS tools already installed."
fi

echo
echo "Step 2: Importing ZFS pool '${POOL_NAME}' (if needed)..."
if zpool list -H -o name 2>/dev/null | grep -qx "${POOL_NAME}"; then
  echo "  Pool '${POOL_NAME}' is already imported."
else
  if zpool import | awk '{print $1}' | grep -qx "${POOL_NAME}"; then
    echo "  Importing pool '${POOL_NAME}'..."
    zpool import "${POOL_NAME}"
  else
    echo "ERROR: Pool '${POOL_NAME}' not found in 'zpool import' output." >&2
    exit 1
  fi
fi

echo
echo "Step 3: Setting pool mountpoint to '${MOUNTPOINT}'..."
current_mp="$(zfs get -H -o value mountpoint "${POOL_NAME}")"
if [[ "${current_mp}" != "${MOUNTPOINT}" ]]; then
  echo "  Current mountpoint: ${current_mp} -> updating to ${MOUNTPOINT}"
  mkdir -p "${MOUNTPOINT}"
  zfs set mountpoint="${MOUNTPOINT}" "${POOL_NAME}"
else
  echo "  Mountpoint already set to ${MOUNTPOINT}"
fi

echo "  Ensuring pool is mounted..."
zfs mount "${POOL_NAME}" || true

echo
echo "Step 4: Creating directory layout under ${MOUNTPOINT}..."
mkdir -p \
  "${MOUNTPOINT}/media" \
  "${MOUNTPOINT}/apps"

echo "  - Ensured ${MOUNTPOINT}/media exists (for photos, music, tv, movies, torrents, backups)"
echo "  - Ensured ${MOUNTPOINT}/apps exists (for k3s application data/config)"

echo
echo "Step 5: Migrating legacy layout (if present)..."

# Move old top-level 'config' directory to 'legacy-config' to avoid
# mixing OMV-era configs with the new k3s-friendly 'apps/' layout.
if [[ -d "${MOUNTPOINT}/config" && ! -d "${MOUNTPOINT}/legacy-config" ]]; then
  echo "  - Moving ${MOUNTPOINT}/config -> ${MOUNTPOINT}/legacy-config"
  mv "${MOUNTPOINT}/config" "${MOUNTPOINT}/legacy-config"
else
  echo "  - No legacy 'config' directory to move (or 'legacy-config' already exists)."
fi

# Flatten common double-nested movies directory: media/movies/movies -> media/movies
if [[ -d "${MOUNTPOINT}/media/movies/movies" ]]; then
  echo "  - Flattening ${MOUNTPOINT}/media/movies/movies into ${MOUNTPOINT}/media/movies"
  mv "${MOUNTPOINT}/media/movies/movies/"* "${MOUNTPOINT}/media/movies/" 2>/dev/null || true
  rmdir "${MOUNTPOINT}/media/movies/movies" 2>/dev/null || true
else
  echo "  - No nested 'media/movies/movies' directory detected."
fi

# Ensure common media directories exist for qBittorrent and related apps
mkdir -p \
  "${MOUNTPOINT}/media/torrents" \
  "${MOUNTPOINT}/media/downloads" \
  "${MOUNTPOINT}/media/movies" \
  "${MOUNTPOINT}/media/music" \
  "${MOUNTPOINT}/media/tv" \
  "${MOUNTPOINT}/media/games" \
  "${MOUNTPOINT}/media/books"

echo "  - Ensured ${MOUNTPOINT}/media/torrents exists"
echo "  - Ensured ${MOUNTPOINT}/media/{downloads,movies,music,tv,games,books} exist"

echo
echo "Step 6: Migrating legacy 'autres downloads' into downloads/misc (if present)..."

LEGACY_DL_DIR="${MOUNTPOINT}/media/backup/autres downloads"
TARGET_MISC_DIR="${MOUNTPOINT}/media/downloads/misc"

if [[ -d "${LEGACY_DL_DIR}" ]]; then
  echo "  - Found legacy downloads at: ${LEGACY_DL_DIR}"
  mkdir -p "${TARGET_MISC_DIR}"
  echo "  - Moving contents to: ${TARGET_MISC_DIR}"
  # Move contents but leave the original directory structure minimal
  shopt -s dotglob nullglob
  mv "${LEGACY_DL_DIR}/"* "${TARGET_MISC_DIR}/" 2>/dev/null || true
  shopt -u dotglob nullglob
  # Optionally remove the now-empty legacy directory
  rmdir "${LEGACY_DL_DIR}" 2>/dev/null || true
else
  echo "  - No legacy 'backup/autres downloads' directory to migrate."
fi

echo
echo
echo "Step 7: Setting ownership on apps directory..."
chown -R "${PUID}:${PGID}" "${MOUNTPOINT}/apps"
echo "  - Set ${MOUNTPOINT}/apps ownership to ${PUID}:${PGID}"
echo "  - Existing media under ${MOUNTPOINT}/media was left unchanged; adjust as needed."

echo
echo "Summary:"
echo "  - Pool '${POOL_NAME}' imported and mounted at '${MOUNTPOINT}'."
echo "  - Base directories created:"
echo "      ${MOUNTPOINT}/media"
echo "      ${MOUNTPOINT}/apps"
echo "  - ${MOUNTPOINT}/apps owned by ${PUID}:${PGID}."
echo
echo "Next steps:"
echo "  - Set STORAGE_BASE=${MOUNTPOINT} in docker/.env.prod and k3s-related env."
echo "  - Review existing directories under ${MOUNTPOINT} (e.g., 'config/', 'media/')."
echo "  - Optionally archive legacy config (e.g., move '${MOUNTPOINT}/config' to '${MOUNTPOINT}/legacy-config')."
echo
echo "Done."

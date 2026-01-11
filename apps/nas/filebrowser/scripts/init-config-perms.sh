#!/bin/bash
set -e

echo "=== Filebrowser Config Permissions Initialization ==="

mkdir -p /config
# Only chown if needed; root-squashed volumes will reject chown even when already owned.
if [ "$(stat -c %u /config)" != "1000" ]; then
  chown -R 1000:1000 /config || echo "WARN: unable to chown /config (root_squash?)"
fi
# Ensure top-level media dirs are writable by the app user.
find /srv -maxdepth 1 -type d ! -user 1000 -exec chown 1000:1000 {} + 2>/tmp/chown.log || echo "WARN: unable to chown /srv (root_squash?)"

echo "=== Config permissions initialization complete ==="

#!/bin/bash
set -eu

echo "=== Filebrowser Initialization ==="

DB_PATH="/config/filebrowser.db"
CONFIG_PATH="/config/settings.json"

cat > "${CONFIG_PATH}" <<'EOF'
{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/config/filebrowser.db",
  "root": "/srv"
}
EOF

if [ ! -f "${DB_PATH}" ]; then
  echo "Initializing filebrowser database..."
  /filebrowser config init "${DB_PATH}"
fi

# Always ensure admin user exists (update if already present)
if /filebrowser --database "${DB_PATH}" users update "${FB_USERNAME}" "${FB_PASSWORD}" --perm.admin --scope "." 2>/dev/null; then
  echo "Admin user updated"
elif /filebrowser --database "${DB_PATH}" users add "${FB_USERNAME}" "${FB_PASSWORD}" --perm.admin --scope "." 2>/dev/null; then
  echo "Admin user created"
else
  echo "Admin user already configured (or error during setup)"
fi

echo "=== Filebrowser initialization complete ==="

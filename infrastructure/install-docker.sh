#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Docker Engine on Ubuntu (24.04 intended) and add a user to the docker group.
# Usage: sudo TARGET_USER=nasadmin ./infrastructure/install-docker.sh

TARGET_USER="${TARGET_USER:-nasadmin}"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo TARGET_USER=$TARGET_USER $0)" >&2
  exit 1
fi

echo "Installing Docker Engine for user: $TARGET_USER"

echo "Removing old Docker packages (if any)..."
apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

echo "Updating apt and installing prerequisites..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

echo "Adding Docker GPG key and repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH="$(dpkg --print-architecture)"
CODENAME="$(lsb_release -cs)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list

echo "Installing Docker Engine, CLI, Buildx, and Compose plugin..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Writing /etc/docker/daemon.json with sane defaults..."
cat >/etc/docker/daemon.json <<'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "Enabling and restarting Docker..."
systemctl enable docker
systemctl restart docker

echo "Ensuring docker group exists and adding user..."
groupadd -f docker
if id "$TARGET_USER" >/dev/null 2>&1; then
  usermod -aG docker "$TARGET_USER"
else
  echo "User '$TARGET_USER' not found; create the user and rerun group addition." >&2
fi

echo
echo "Done."
echo "- User '$TARGET_USER' must log out and back in for docker group membership to apply."
echo "- Verify: sudo -u $TARGET_USER docker ps"

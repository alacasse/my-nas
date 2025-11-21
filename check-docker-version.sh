#!/bin/bash

# Function to compare versions
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

# Get Docker Server API version
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
API_VERSION=$(docker version --format '{{.Server.APIVersion}}')
MIN_API_VERSION=$(docker version --format '{{.Server.MinAPIVersion}}')

echo "Detected Docker Version: $DOCKER_VERSION (API: $API_VERSION, Min API: $MIN_API_VERSION)"

# Check if Docker version is >= 29 (which implies API >= 1.44 and Min API usually higher than 1.41 support)
# Docker 29.0.0 has API 1.44. Portainer needs 1.41.
# If MinAPIVersion is > 1.41, Portainer will fail.

# Simple check: If Major version is >= 29, warn user.
MAJOR_VERSION=$(echo $DOCKER_VERSION | cut -d. -f1)

if [ "$MAJOR_VERSION" -ge 29 ]; then
    echo "----------------------------------------------------------------"
    echo "WARNING: Incompatible Docker Version Detected!"
    echo "----------------------------------------------------------------"
    echo "You are running Docker version $DOCKER_VERSION."
    echo "Portainer currently requires a Docker version that supports API 1.41."
    echo "Docker v29+ has dropped support for older APIs in some configurations."
    echo ""
    echo "Recommended Action: Downgrade to Docker v27.x"
    echo ""
    read -p "Do you want to proceed anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting setup."
        exit 1
    fi
else
    echo "Docker version check passed."
fi

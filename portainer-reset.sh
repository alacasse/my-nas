#!/bin/bash
set -e

echo "Resetting Portainer..."
docker stop portainer || true
docker rm portainer || true
docker volume rm portainer_portainer_data || true

# Re-run setup to recreate volume and start container
./portainer-setup.sh

echo "Portainer reset complete. Go to http://portainer.nas.test:9000 to set your admin password."

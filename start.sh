#!/bin/bash

# Check execution context
./check-vm-context.sh || exit 1

echo "Start services"
./vpn-torrent-setup.sh
./nginx-setup.sh
./nas-setup.sh
./postgres-setup.sh
./portainer-setup.sh

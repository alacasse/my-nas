#!/bin/bash

echo "Start services"
./vpn-torrent-setup.sh
./nginx-setup.sh
./nas-setup.sh
./portainer-setup.sh

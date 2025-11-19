#!/bin/bash

echo "Stop services"
./nginx-teardown.sh
./nas-teardown.sh
./portainer-teardown.sh
./vpn-torrent-teardown.sh
echo "All services stopped."

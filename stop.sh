#!/bin/bash

echo "Stop services"
./nginx-teardown.sh
./vpn-torrent-teardown.sh
echo "All services stopped."

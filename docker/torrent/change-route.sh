#!/bin/bash
set -euo pipefail
echo "Changing default route to VPN..."
ip route del default
ip route add default via 172.18.0.2
echo "Setting MTU to 1320 to match WireGuard..."
ip link set dev eth0 mtu 1320

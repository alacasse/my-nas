#!/bin/bash
set -e

echo "Current routes:"
ip route show

echo "Changing default route to VPN (172.18.0.2)..."
# Delete default route if it exists
ip route del default || echo "No default route to delete"

# Add new default route via VPN container
ip route add default via 172.18.0.2 dev eth0

echo "Setting MTU to 1320 to match WireGuard..."
ip link set dev eth0 mtu 1320

echo "New routes:"
ip route show

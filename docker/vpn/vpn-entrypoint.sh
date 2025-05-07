#!/bin/bash
set -e

echo "Setting up IP forwarding and NAT..."

# Enable forwarding if not already
# sysctl -w net.ipv4.ip_forward=1

# Allow forwarding from vpn_net subnet
iptables -C FORWARD -s 172.18.0.0/16 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -s 172.18.0.0/16 -j ACCEPT

iptables -C FORWARD -d 172.18.0.0/16 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -d 172.18.0.0/16 -j ACCEPT

# Set up NAT masquerading for outbound traffic
iptables -t nat -C POSTROUTING -s 172.18.0.0/16 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 172.18.0.0/16 -j MASQUERADE

echo "Starting Gluetun..."
exec /gluetun-entrypoint

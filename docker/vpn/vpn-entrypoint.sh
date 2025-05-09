#!/bin/bash
set -e

echo "Setting up IP forwarding and NAT..."

# Accept all outbound traffic from this container
iptables -A OUTPUT -s 172.18.0.2 -j ACCEPT

# Accept all traffic going out tun0 (for forwarded packets)
iptables -A OUTPUT -o tun0 -j ACCEPT

# iptables -A OUTPUT -s 172.18.0.10 -o tun0 -j ACCEPT

# Accept all outbound traffic from any server in the 172.18.0.0/16 subnet through tun0
iptables -A OUTPUT -s 172.18.0.0/16 -o tun0 -j ACCEPT

# Allow forwarding from vpn_net subnet
iptables -C FORWARD -s 172.18.0.0/16 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -s 172.18.0.0/16 -j ACCEPT

iptables -C FORWARD -d 172.18.0.0/16 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -d 172.18.0.0/16 -j ACCEPT

# Allow forwarding from vpn_net subnet to tun0
iptables -A FORWARD -s 172.18.0.0/16 -o tun0 -j ACCEPT

# Allow return traffic from tun0 to vpn_net subnet
iptables -A FORWARD -d 172.18.0.0/16 -i tun0 -j ACCEPT

# Set up NAT masquerading for outbound traffic
iptables -t nat -C POSTROUTING -s 172.18.0.0/16 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 172.18.0.0/16 -j MASQUERADE

# Set up NAT masquerading for outbound traffic from vpn_net subnet through tun0
iptables -t nat -A POSTROUTING -s 172.18.0.0/16 -o tun0 -j MASQUERADE

# Forward port 8080 from host to torrent container
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 172.18.0.10:8080
iptables -t nat -A POSTROUTING -p tcp -d 172.18.0.10 --dport 8080 -j MASQUERADE

echo "Starting Gluetun..."
exec /gluetun-entrypoint
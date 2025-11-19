#!/bin/bash
set -euo pipefail
echo "Changing default route to VPN..."
ip route del default
ip route add default via 172.18.0.2

#!/usr/bin/env bash
set -euo pipefail

# Sanity checks for vpn + torrent compose stack.
# - Verifies networks exist
# - Verifies containers are running/healthy
# - Optional connectivity checks via curl (best-effort)

NETWORKS=("vpn_net" "lan_net")
CONTAINERS=("vpn" "torrent")

fail=0

echo "Checking Docker networks..."
for net in "${NETWORKS[@]}"; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    echo "  [ok] $net exists"
  else
    echo "  [FAIL] $net missing"
    fail=1
  fi
done

echo "Checking container states..."
for c in "${CONTAINERS[@]}"; do
  if ! docker inspect "$c" >/dev/null 2>&1; then
    echo "  [FAIL] $c not found"
    fail=1
    continue
  fi
  status=$(docker inspect -f '{{.State.Status}}' "$c")
  health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$c")
  echo "  [$status] $c (health: $health)"
  if [[ "$status" != "running" ]]; then
    fail=1
  fi
  if [[ "$health" == "unhealthy" ]]; then
    fail=1
  fi
done

echo "Connectivity checks (best-effort)..."
if docker exec vpn sh -c "command -v curl" >/dev/null 2>&1; then
  vpn_http_cmd="curl -fsS --max-time 8"
elif docker exec vpn sh -c "command -v wget" >/dev/null 2>&1; then
  vpn_http_cmd="wget -qO- --timeout=8"
else
  vpn_http_cmd=""
fi

if [ -n "$vpn_http_cmd" ]; then
  if ip_out=$(docker exec vpn sh -c "$vpn_http_cmd https://ifconfig.io/ip" 2>/dev/null); then
    echo "  [ok] VPN external IP: $ip_out"
  else
    echo "  [warn] Could not fetch external IP (network blocked or tool failed)"
  fi
  if docker exec vpn sh -c "$vpn_http_cmd http://torrent:8080" >/dev/null 2>&1; then
    echo "  [ok] Torrent UI reachable from vpn container (http://torrent:8080)"
  else
    echo "  [warn] Torrent UI not reachable from vpn container"
  fi
else
  echo "  [warn] No curl/wget in vpn container; rebuild vpn image to add tools (see docker/vpn/Dockerfile)"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Finished with failures."
  exit 1
fi

echo "All checks passed (with possible warnings above)."

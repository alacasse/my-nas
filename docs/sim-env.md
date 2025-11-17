# Local Simulation (k3d on Docker)

Use k3d (k3s-in-Docker) on your Fedora dev machine to rehearse manifests and ingress before deploying k3s on the NAS.

## Prerequisites
- Docker running locally (cgroup driver set to `systemd` is preferred).
- Installed binaries: k3d, kubectl, and optionally kustomize.
- Repo checked out locally.

## Start a k3d cluster
```bash
k3d cluster create nas-sim \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer"
kubectl config use-context k3d-nas-sim
```

## Deploy manifests (dev overlay)
```bash
kustomize build clusters/dev | kubectl apply -f -
kubectl get pods -A
kubectl get ingress -A
```
If you don’t have kustomize, use `kubectl kustomize clusters/dev | kubectl apply -f -`.

## Test access
- Hit ingress endpoints on `http://localhost` (and `https://localhost` if you map 443).
- Check logs: `kubectl logs -n <namespace> <pod>`.
- Add hosts entries for friendly names (e.g., `portainer.localhost` -> 127.0.0.1).

## VPN/torrent (optional)
- Run compose helpers on the host for routing tests:
  - Start: `./vpn-torrent-setup.sh`
  - Stop: `./vpn-torrent-teardown.sh`

## Teardown
```bash
k3d cluster delete nas-sim
```

## Notes
- This matches k3s behavior closely (Traefik default ingress, local-path storage), but hardware-specific items (ZFS, NIC passthrough) still need the NAS to validate.

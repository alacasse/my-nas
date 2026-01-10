# qBittorrent

qBittorrent with VPN support (binhex/arch-qbittorrentvpn) deployed to the `torrents` namespace.

## Scripts

Scripts are stored as plain files in `scripts/` and packaged into a ConfigMap via Kustomize's `configMapGenerator`.

| Script | Purpose | Lifecycle |
|--------|---------|-----------|
| `init.sh` | Creates directories, copies default configs | Init container (runs before main app) |

### How it works

1. Scripts live in `scripts/` as standalone `.sh` files
2. `kustomization.yaml` uses `configMapGenerator` to create the `qbittorrent-scripts` ConfigMap
3. The Deployment mounts this ConfigMap as a volume at `/scripts`
4. Init container executes scripts via `command: ["/bin/sh", "/scripts/init.sh"]`

### Adding new scripts

1. Add script file to `scripts/`
2. Add filename to `configMapGenerator.files` in `kustomization.yaml`
3. Mount and execute in the appropriate container/init container

## Configuration

Default qBittorrent settings are stored in `configmap.yaml`:
- `qBittorrent.conf` - Main application config
- `categories.json` - Download category definitions (templated with `QBIT_MEDIA_ROOT`)
- `watched_folders.json` - Auto-import folder settings

These are mounted at `/defaults` and copied to `/config` on first run by `init.sh`.

## Volumes

| Volume | Mount Path | Purpose |
|--------|------------|---------|
| `qbittorrent-config` (PVC) | `/config` | Persistent app config & logs |
| `nas-downloads` (PVC) | `/data` | Downloads and media storage |
| `vpn-config` (Secret) | `/config/openvpn` | VPN credentials |

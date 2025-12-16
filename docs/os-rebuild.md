# OS Rebuild and ZFS Pool Import (NAS)

This document describes how to reinstall Ubuntu on the NAS SSD, re‑attach the existing ZFS pool, and prepare the storage layout for the new k3s‑based stack.

The goals are:
- Preserve the existing ZFS pool **`nas`** and all data.
- Mount the pool at **`/mnt/storage`**.
- Establish a clear directory structure for media and application data.

> WARNING: These steps assume disks containing the `nas` pool are left intact during OS reinstall. Double‑check disk selection during Ubuntu install.

## 1. Install Ubuntu and ZFS Packages

1. Install Ubuntu Server 24.04 LTS on the SSD (do **not** partition/format the HDDs that carry the ZFS pool).
2. After first boot, install ZFS support:
   ```bash
   sudo apt update
   sudo apt install -y zfsutils-linux
   ```

## 2. Import the Existing ZFS Pool

List available pools:
```bash
sudo zpool import
```

You should see a pool named `nas`. Import it:
```bash
sudo zpool import nas
```

Verify:
```bash
zpool status nas
zfs list
```

Depending on previous configuration, the pool may mount at `/nas` or another mountpoint.

## 3. Set Mountpoint to `/mnt/storage`

We standardize on `/mnt/storage` as the root for all persistent data.

1. Create the target directory:
   ```bash
   sudo mkdir -p /mnt/storage
   ```

2. Set the pool (or its primary dataset) mountpoint:
   ```bash
   sudo zfs set mountpoint=/mnt/storage nas
   sudo zfs mount nas
   ```

3. Confirm:
   ```bash
   zfs list | grep nas
   ls -la /mnt/storage
   ```

At this point, the existing directory tree (previously under `/nas`) should be visible under `/mnt/storage`.

### Using the Helper Script

Instead of running the commands above manually, you can use the helper script in this repo:

```bash
cd /path/to/my-nas
sudo ./infrastructure/os-install/post-install-storage.sh
```

The script:
- Installs `zfsutils-linux` if needed.
- Imports pool `nas` (configurable via `POOL_NAME`).
- Sets the mountpoint to `/mnt/storage` (configurable via `MOUNTPOINT`).
- Creates `/mnt/storage/media` and `/mnt/storage/apps`.
- Adjusts ownership of `/mnt/storage/apps` to UID/GID 1000 by default (configurable via `PUID`/`PGID`).

## 4. Target Directory Layout

We aim for the following high‑level layout under `/mnt/storage`:

```text
/mnt/storage
├── media/           # Long-term media library
│   ├── photos/
│   ├── music/
│   ├── tv/
│   ├── movies/
│   ├── torrents/
│   └── backup/
└── apps/            # Data/config for k3s applications
    ├── qbittorrent/
    │   ├── config/
    │   └── logs/
    ├── portainer/
    │   └── data/
    ├── homepage/
    │   └── config/
    └── ...          # other apps (observability, file services, etc.)
```

Existing paths like `/mnt/storage/media/...` should be preserved; new `apps/` subdirectories will be created as the k3s stack is built out.

The old `config/` tree under the pool can be:
- Left in place as **legacy config** until everything is migrated, or
- Moved under a dedicated archive directory (e.g., `/mnt/storage/legacy-config/`) for reference.

## 5. Permissions

The k3s workload pods will typically run as UID/GID `1000` (or another non‑root user). Ensure this user has access to the storage tree:

```bash
sudo chown -R 1000:1000 /mnt/storage
# or, if you prefer more granular control:
sudo chown -R 1000:1000 /mnt/storage/media
sudo chown -R 1000:1000 /mnt/storage/apps
```

You can refine ownership later per directory or per dataset if needed.

## 6. Environment Configuration

On the NAS host:

- Set `STORAGE_BASE` to `/mnt/storage` in the relevant environment files (e.g., `docker/.env.prod` for transitional Docker usage, and any future systemd/environment overrides used by k3s tooling).
- Verify:
  ```bash
  echo \"STORAGE_BASE=/mnt/storage\" >> docker/.env.prod
  ```

Kubernetes manifests in this repo assume that:

- `STORAGE_BASE=/mnt/storage`
- Media lives under `${STORAGE_BASE}/media/...`
- Application data/config lives under `${STORAGE_BASE}/apps/<app>/...`

## 7. Future: ZFS Datasets for Kubernetes

Later, when configuring the ZFS CSI driver (democratic‑csi) for k3s, you may want to:

- Create child datasets under `nas` for more granular control (snapshots/quotas), e.g.:
  - `nas/media`
  - `nas/apps`
- Configure the StorageClass to create per‑PVC datasets under `nas/apps` (or similar).

These steps are not required for the initial migration but will give you finer control over Kubernetes‑managed volumes.

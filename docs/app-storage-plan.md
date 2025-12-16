# Application Storage Plan

This document captures how we want **one global pattern** for where application files live (on RAID / ZFS, via Kubernetes PVCs), while still allowing **per‑app specifics** where images require different paths or layouts.

The goal is:
- Data and config always live on the NAS RAID, not inside ephemeral k3s nodes.
- Dev (k3d / hostPath) and prod (k3s / ZFS CSI) follow the same logical layout.
- Each app’s manifests look similar, with only app‑specific differences.

## Objectives

- Keep **all important state** (configs, downloads, logs, databases) on ZFS.
- Use **Kubernetes PVCs** as the abstraction, not bare host paths.
- Make **dev vs prod** differ only in the storage backend, not in app manifests.
- Provide a **repeatable pattern** to apply to every app (qbittorrent, Portainer, observability, NAS/file services, etc.).

## Global Storage Model

We assume a single RAID‑backed root exposed via `STORAGE_BASE`:

- On the NAS:
  - ZFS pool name: **`nas`**
  - The pool (or its primary dataset) is mounted at **`/mnt/storage`**.
- `STORAGE_BASE` in production is set to `/mnt/storage`.

Within that root, we standardize on:

- `${STORAGE_BASE}/apps/<app>/config` – application configuration files.
- `${STORAGE_BASE}/apps/<app>/data` – application data (where meaningful).
- `${STORAGE_BASE}/media/...` – shared media library (photos, music, tv, movies, torrents, backups).
- `${STORAGE_BASE}/downloads` – shared downloads directory (optional; may overlap with `media`).
- `${STORAGE_BASE}/logs/<app>` – logs (optional; some apps log inside config/data).

This layout should be mirrored in development (hostPath under `/home/ubuntu/nas-volumes/...`) and in production (ZFS datasets via democratic‑csi).

## Kubernetes Pattern

At the Kubernetes level, we want a small, repeatable pattern:

- **PVC naming**
  - `<app>-config` – config files for one app.
  - `<app>-data` – primary data for one app (if needed).
  - `nas-downloads`, `nas-torrents`, `nas-storage` – shared NAS PVCs for cross‑app data.
- **Base manifests**
  - `apps/<app>/pvc.yaml` declares the PVCs without `storageClassName`.
  - `apps/<app>/deployment.yaml` mounts those PVCs at the paths the image expects (e.g. `/config`, `/data`, `/var/lib/...`).
- **Environment overlays**
  - `clusters/dev`: binds PVCs to `hostPath` PVs (`dev-hostpath`) under `/home/ubuntu/nas-volumes/...`.
  - `clusters/prod`: sets `storageClassName: zfs-nfs` (or another ZFS SC) so PVCs are backed by ZFS datasets on the NAS.

This keeps app manifests environment‑agnostic: only overlays know whether storage is hostPath (dev) or ZFS (prod).

## Volume Mount Strategy

The preferred approach is to **mount PVCs exactly at the paths expected by the container image**, following upstream docs where possible:

- Config PVC → mounted to `/config` (or the image’s documented config directory).
- Data PVC(s) → mounted to `/data`, `/data/downloads`, `/data/torrents`, etc.
- Logs → either inside config/data or mounted to a dedicated log directory.

Where multiple directories should share one PVC (e.g. config + data under a single NAS root), we can use:

- A single PVC (e.g. `nas-storage`) with multiple `volumeMount`s using `subPath`, or
- Multiple PVCs that map more directly to app concepts (`<app>-config`, `<app>-data`).

Small initContainers are allowed to:
- Ensure directories exist inside the mounted volume.
- Seed default config files **only if missing** (ConfigMap as seed, PVC as source of truth).

We want to avoid complex symlink schemes unless absolutely necessary.

## App‑Specific Specialization

Each application may have slightly different expectations for config and data paths. The global pattern above stays the same, but each app can specialize:

- **qBittorrent (binhex/arch-qbittorrentvpn)**
  - Upstream image expects:
    - Config at `/config`.
    - Data (downloads/torrents) at `/data`.
  - Plan:
    - `qbittorrent-config` PVC → mount at `/config`.
    - `nas-downloads` + `nas-torrents` PVCs (or a shared `nas-storage` PVC) → mount at `/data/downloads` and `/data/torrents`.
    - InitContainer copies default `qBittorrent.conf`, `categories.json`, `watched_folders.json` from a ConfigMap into `/config/...` **only if** they do not already exist.

- **Portainer**
  - Image expects persistent data at `/data`.
  - Plan:
    - `portainer-data` PVC → mount at `/data`.
    - No extra init step needed beyond directory creation; Portainer manages its own config files.

- **Observability stack (Prometheus/Grafana/Loki/etc.)**
  - Some components have separate “config” vs “data” directories.
  - Plan:
    - Use ConfigMaps for configs that should be Git‑driven.
    - Use PVCs for data (TSDB, dashboards, logs).
    - Optionally mirror the Docker `CONFIG_MODE` idea (dev vs prod) by having different overlays, but keep the underlying PVC pattern the same.

- **NAS/file services (Samba, FileBrowser, etc.)**
  - These will likely share the same `downloads` / `torrents` trees and additional datasets.
  - Plan:
    - Reuse shared NAS PVCs (`nas-downloads`, `nas-torrents`, others as needed).
    - Mount them at the paths required by each container (e.g. `/srv/nas`, `/shares/...`).

For each new app, we will:
1. Identify the image’s config and data directories (from upstream docs).
2. Map them to PVCs following the naming/layout above.
3. Use initContainers only where default seeding or directory creation is needed.

## Implementation Roadmap

Short‑term steps:
- Finalize and document the RAID/ZFS layout (exact `STORAGE_BASE` and subdirectories).
- Refine qBittorrent manifests to follow the `/config` and `/data` pattern from the image docs, backed by the shared NAS PVCs.
- Validate persistence in dev (k3d/k3s) by restarting pods and nodes, ensuring configs and torrents survive.

Longer term:
- Apply the same pattern to Portainer, observability, and NAS/file services.
- Add brief “Storage” subsections to each app’s README or Kustomize base explaining which PVCs it uses and how they map to `${STORAGE_BASE}`.
- Align ZFS CSI configuration so that PVC names map predictably to ZFS datasets (e.g. `tank/k3s/apps/<app>`).

This gives us a **single mental model** for where data lives, while still letting each app conform to its own upstream conventions.

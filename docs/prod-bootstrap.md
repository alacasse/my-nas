# Production Bootstrap Checklist (NAS)

This document describes the end‑to‑end flow to rebuild the NAS from bare metal to a running k3s cluster with Flux, ZFS‑backed storage, and workloads like qBittorrent.

The steps assume:
- ZFS pool is named `nas`.
- The pool (or its primary dataset) is mounted at `/mnt/storage`.
- This repository is the single source of truth for OS tooling, k3s manifests, and app configuration.

> Tip: Run each section in order. The scripts are written to be re‑runnable where practical.

## 1. Install Ubuntu with Autoinstall

On a workstation (not the NAS), follow `infrastructure/os-install/README.md`:

1. Download the official Ubuntu Server 24.04.3 LTS ISO.
2. Customize `infrastructure/os-install/autoinstall.yaml` (hostname, user, SSH key, password hash, target disk ID).
3. Build the autoinstall ISO:
   ```bash
   cd infrastructure/os-install
   ./build-autoinstall-iso.sh ubuntu-24.04.3-live-server-amd64.iso
   ```
4. Test locally with:
   ```bash
   ./run-autoinstall-vm.sh artifacts/ubuntu-24.04.3-autoinstall.iso
   ```
5. Mount the ISO via IPMI/virtual media and boot the NAS from it to perform the real SSD install.

## 2. Import ZFS Pool and Set Layout

After the NAS boots into the new Ubuntu install:

1. SSH into the NAS and clone this repo (if not already present):
   ```bash
   git clone git@github.com:<user>/my-nas.git ~/my-nas
   cd ~/my-nas
   ```
2. Run the storage post‑install script:
   ```bash
   sudo ./infrastructure/os-install/post-install-storage.sh
   ```

This will:
- Ensure `zfsutils-linux` is installed.
- Import the `nas` pool.
- Set its mountpoint to `/mnt/storage` and mount it.
- Create `/mnt/storage/media` and `/mnt/storage/apps`.
- Move any legacy `config/` directory to `/mnt/storage/legacy-config` if present.
- Ensure `/mnt/storage/media/torrents` and `/mnt/storage/media/downloads` exist.
- Set ownership on `/mnt/storage/apps` to `1000:1000` (configurable via `PUID`/`PGID`).

You can validate:
```bash
zpool status nas
zfs list | grep nas
ls -la /mnt/storage
```

## 3. Install k3s

Install a single‑node k3s cluster on the NAS. You can use upstream docs or a future `infrastructure/k3s-install/` helper. A typical pattern:

```bash
curl -sfL https://get.k3s.io | sh -
```

Verify:
```bash
sudo k3s kubectl get nodes
```

The kubeconfig is usually at `/etc/rancher/k3s/k3s.yaml`.

## 4. Bootstrap Flux (GitOps)

With k3s running and this repo cloned on the NAS:

1. Ensure you have an `age` key on the NAS (or copy one from your workstation):
   - `~/.config/sops/age/keys.txt` should exist.
2. Run the k3s post‑install helper in **prod** mode:
   ```bash
   cd ~/my-nas
   sudo GITHUB_USER=<your-github-username> ./infrastructure/k3s-post-install.sh prod
   ```

This will:
- Verify k3s is up.
- Install the Flux CLI if missing.
- Bootstrap Flux against your GitHub repo (`my-nas`) pointing at `clusters/prod`.
- Create the `sops-age` secret in `flux-system` from your `age` key so Flux can decrypt `secrets.enc.yaml`.

You can check Flux:
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
flux check
flux get kustomizations -A
```

## 5. Install democratic‑csi and ZFS StorageClass

Next, configure ZFS‑backed dynamic volumes for app‑specific PVCs:

1. From the repo root on the NAS:
   ```bash
   cd ~/my-nas
   sudo ./infrastructure/k3s-storage-setup.sh
   ```

This script will:
- Use `/etc/rancher/k3s/k3s.yaml` as `KUBECONFIG` (override with `KUBECONFIG_PATH` if needed).
- Ensure Helm is installed.
- Install/upgrade the `democratic-csi` Helm chart using `infrastructure/democratic-csi/values-zfs-nfs.yaml`.
- Wait for democratic‑csi pods to be ready.
- Verify that a `StorageClass` named `zfs-nfs` exists.

Review and tune `infrastructure/democratic-csi/values-zfs-nfs.yaml` as needed before first production use (dataset parents, compression, etc.).

## 6. Let Flux Deploy Apps (including qBittorrent)

With Flux and storage in place, Flux will reconcile `clusters/prod` and deploy:

- Namespaces and base apps from `apps/base`.
- qBittorrent, Portainer, Homepage, etc.

Key storage behavior:
- PVCs like `qbittorrent-config` and `portainer-data` use the `zfs-nfs` StorageClass and are provisioned as ZFS datasets under `nas/k3s-pv/...`.
- `nas-downloads` and `nas-torrents` PVCs bind to static PVs in `clusters/prod/pv.yaml`:
  - `/mnt/storage/media/downloads`
  - `/mnt/storage/media/torrents`

Check workloads:
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods -A
kubectl -n torrents get pods
kubectl -n management get pods
```

Verify qBittorrent via ingress:
- Ensure DNS/hosts entry for `torrent.nas.test` pointing at the NAS.
- Browse to `http://torrent.nas.test` (Traefik ingress fronting the qbittorrent Service).

## 7. Ongoing Operations

Once bootstrapped:
- All changes to k3s workloads should go through Git (this repo) and be reconciled by Flux.
- Storage changes should be reflected in:
  - `docs/app-storage-plan.md` (conceptual model).
  - `infrastructure/os-install/post-install-storage.sh` (host layout).
  - `infrastructure/democratic-csi/values-zfs-nfs.yaml` (ZFS CSI behavior).

If the NAS SSD ever needs to be reinstalled:
- Re-run this checklist starting from section 1, using the same Git repository and scripts.


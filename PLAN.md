# NAS Rebuild Plan

## Confirmed Facts
- Hardware: Supermicro NAS with 4 HDDs in a ZFS RAID pool for data plus a 128 GB SSD currently running OpenMediaVault (Debian-based).
- Current stack: Docker runs on OMV today.
- Goal: Replace the SSD with a fresh OS install and run all NAS services in a single-node k3s environment managed by this project.
- Requirement: Preserve the existing ZFS pool and data; new OS must have first-class ZFS support.
- Development workflow: this repository is the single source of truth for both infrastructure code and application manifests.

## Open Questions
1. Which OS will replace OpenMediaVault (e.g., Debian, Ubuntu Server, TrueNAS SCALE, etc.)? Needs strong ZFS tooling and support for k3s prerequisites.
2. What exact services must run in k3s (file sharing protocols, VPN, torrents, media, management UIs)? Are there new ones beyond the old Docker set?
3. How should persistent storage be organized inside Kubernetes (datasets → PVCs, shared StorageClasses)?
4. What networking layout is required (ingress strategy, VPN routing, LAN exposure, SSL/TLS, etc.)?
5. Which observability and data services (monitoring stack, database) should be part of the baseline?

## Immediate Next Steps
1. **Select Target OS**
   - Target: Ubuntu Server 24.04.3 LTS (official ZFS support, long-term updates).
   - Confirm installation of `zfs-dkms`, kernel headers, and other prerequisites for k3s.
2. **Plan ZFS Preservation**
   - Document current pool/dataset names and mountpoints.
   - Outline export/import steps to ensure the pool can be remounted after the OS reinstall.
   - Consider backups or snapshots before hardware changes.
   - For testing: recreate a small ZFS pool inside a local VM to validate automation/scripts before touching production disks.
3. **Define Kubernetes Baseline**
   - Install k3s (likely single-node control plane), decide on bundled components (Traefik ingress, metrics-server).
   - Use a ZFS CSI driver (e.g., democratic-csi) configured against the existing ZFS pool for dynamic PersistentVolumes.
   - Mirror the setup locally by running k3d + the same manifests so CI/local testing equals production as closely as possible.
4. **Catalog Required Services**
   - List all workloads to migrate into k3s along with their storage/network needs.
   - Determine if new services (monitoring, GitOps, etc.) are part of the scope.
5. **Repository Organization / GitOps**
    - Use this repo as the single source of truth for cluster state.
    - Adopt FluxCD for GitOps reconciliation on Ubuntu/k3s: define environments (dev/prod) via Kustomize overlays, let Flux continuously sync.
    - Standardize on Mozilla SOPS (with age or GPG keys) for encrypting secrets in Git; consider RenovateBot for automated dependency updates.
6. **Local Development / Testing**
    - Spin up a local k3d (k3s-in-docker) cluster on the dev workstation for testing manifests before pushing to the NAS.
    - Flux can target the dev cluster via a separate `clusters/dev` overlay while production points to the NAS k3s cluster.
    - Use hostPath or lightweight storage classes locally; production overlays reference the ZFS CSI StorageClass.
    - Automate this path (scripts or CI): create k3d cluster → install Flux → apply manifests → run health checks → destroy cluster.

## Suggested Additional Services
- **Monitoring/Logging Stack** (confirmed)
  - Deploy Prometheus + node-exporter for system metrics and Grafana for visualization.
  - Add Loki (with Promtail or another log shipper) for centralized log aggregation.
  - Persist Prometheus TSDB, Grafana config, and Loki data on ZFS-backed PVCs provided by the CSI driver.
- **Database Layer** (confirmed PostgreSQL)
  - Deploy PostgreSQL via StatefulSet/Helm chart; back data volumes with ZFS CSI PVCs located in the NAS pool.
  - Use PostgreSQL as the standard relational backend for applications (media managers, automation apps, etc.).
- **GitOps Automation**
  - Install FluxCD on the k3s cluster (Ubuntu Server 24.04.3 base) to manage all Kubernetes manifests from this repository.
  - Integrate SOPS for secret encryption (Flux decrypts at apply time) and optionally RenovateBot for automated image/chart updates.
  - Rely on Flux’s continuous reconciliation to prevent drift and provide reproducible homelab infrastructure.
- **Secrets & GitOps**
  - Standardize on FluxCD for Git-driven reconciliation and SOPS for managing encrypted secrets within this repo.

Ensure all persistent data (monitoring TSDB, Grafana dashboards, database data) is mapped to datasets on the NAS ZFS pool via the CSI driver so nothing resides solely on the OS SSD.

## Repository Layout (proposed)
- `docs/` – OS rebuild notes, ZFS import steps, operational runbooks.
- `infrastructure/`
  - `os-install/` – autoinstall/cloud-init files or Ansible playbooks tested inside local VMs before running against the NAS (manual IPMI install is still acceptable; scripts support repeatability).
  - `k3s-install/` – scripts for k3s bootstrap (test inside VM first).
  - `flux-bootstrap/` – automation for Flux install + SOPS key management; should run identically against k3d and NAS clusters.
- `clusters/dev/` and `clusters/prod/` – Flux configuration and Kustomize overlays per environment (dev targets k3d, prod targets NAS k3s).
- `apps/<service>/` – per-application manifests or Helm values (nas services, monitoring stack, PostgreSQL, etc.).
- Optional: `ci/` scripts for local/CI testing (spin up k3d, run smoke tests).

Keep this structure flexible; expand folders as services are defined and onboarded.

Update this plan as soon as the OS choice and service catalog are defined so the next phase (manifests, storage classes, ingress) can be detailed.

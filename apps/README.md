# Applications

Store per-service manifests here (Helm values, Kustomize bases, etc.).

## Directory Structure

```
apps/
├── base/                      # Shared resources (namespaces, kustomization)
│   ├── kustomization.yaml
│   └── namespaces.yaml
├── nas/                       # NAS services
│   └── filebrowser/           # File browser application
├── networking/                # Networking and utilities
│   ├── homepage/              # Dashboard application
│   ├── portainer/             # Container management UI
│   └── qbittorrent/           # Torrent client with VPN
├── monitoring/                # (reserved for future)
│   └── kustomization.yaml     # Prometheus, Grafana, Loki
└── database/                  # (reserved for future)
    └── kustomization.yaml     # PostgreSQL, backups
```

## Category Overview

| Category     | Directory     | Purpose                           | Apps                        |
|--------------|---------------|-----------------------------------|-----------------------------|
| **Shared**   | [`base/`](base/) | Namespaces, shared Kustomize      | `kustomization.yaml`, `namespaces.yaml` |
| **NAS**      | [`nas/`](nas/)   | File services, storage            | `filebrowser`               |
| **Networking** | [`networking/`](networking/) | Ingress, VPN, dashboards | `homepage`, `portainer`, `qbittorrent` |
| **Monitoring** | [`monitoring/`](monitoring/) | Observability (future) | —                           |
| **Database** | [`database/`](database/) | Database services (future) | —                           |

## Notes

- The `base/` directory stays at the root level for shared resources that apply across all categories.
- Category directories contain app-specific subdirectories with Kustomize manifests.
- Reference these directories from the environment overlays under [`clusters/`](../clusters/).

## Usage

Reference app directories from cluster overlays:

```yaml
# clusters/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../apps/base
  - ../../apps/nas/filebrowser
  - ../../apps/networking/homepage
  - ../../apps/networking/portainer
  - ../../apps/networking/qbittorrent
```

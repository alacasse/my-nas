# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This repository manages a homelab NAS infrastructure currently undergoing migration from Docker Compose to Kubernetes (k3s). The project runs on a Supermicro NAS with 4 HDDs in ZFS RAID and a 128 GB SSD.

**Current State**: Docker-based services (file sharing, VPN, torrenting, reverse proxy)  
**Target State**: Single-node k3s cluster on Ubuntu 24.04.3 LTS with GitOps (FluxCD), ZFS CSI storage, and SOPS-encrypted secrets

## Commands

### Docker Commands (Current Setup)

Start all services:
```bash
./start.sh
```

Stop all services:
```bash
./stop.sh
```

Start individual service stacks:
```bash
# NAS services (Samba + FileBrowser)
docker compose --env-file docker/.env.dev -f docker/nas/docker-compose.yml up -d --build

# VPN container
docker compose --env-file docker/.env.dev -f docker/vpn/docker-compose.yml up -d --build

# Torrent (routes through VPN)
docker compose --env-file docker/.env.dev -f docker/torrent/docker-compose.yml up -d --build

# Nginx reverse proxy
docker compose -f docker/nginx/docker-compose.yml up -d --build

# Portainer management UI
docker compose --env-file docker/.env.dev -f docker/portainer/docker-compose.yml up -d --build
```

Stop individual stacks:
```bash
docker compose -f docker/<service>/docker-compose.yml down
```

Inspect running containers:
```bash
docker inspect <container_name>
```

Access services:
- Portainer: `portainer.localhost`
- Torrent UI: `torrent.localhost`
- FileBrowser: `localhost:18080`

### Kubernetes Commands (Planned)

Test manifests locally with k3d:
```bash
# Create local k3d cluster
k3d cluster create nas-dev

# Apply dev overlays
kubectl apply -k clusters/dev/

# Delete cluster
k3d cluster delete nas-dev
```

Bootstrap FluxCD on k3s:
```bash
# From infrastructure/flux-bootstrap/
flux bootstrap git \
  --url=ssh://git@github.com/<user>/my-nas \
  --branch=main \
  --path=clusters/prod
```

Check Flux reconciliation status:
```bash
flux get all
flux logs --all-namespaces --follow
```

### SOPS Secret Management

Encrypt secrets before committing:
```bash
# Encrypt a secret file
sops --encrypt --age <age-public-key> secret.yaml > secret.enc.yaml

# Edit encrypted secret
sops secret.enc.yaml

# Decrypt for inspection
sops --decrypt secret.enc.yaml
```

### ZFS Storage Operations

Import existing pool after OS reinstall:
```bash
# List available pools
zpool import

# Import pool
zpool import <pool-name>

# Check pool status
zpool status

# List datasets
zfs list
```

## Architecture

### Current Docker Architecture

- **Networks**:
  - `lan_net` (172.x.x.x/24): Hosts Samba, FileBrowser, Nginx, and Torrent's LAN-accessible interface
  - `vpn_net` (10.x.x.x/24): Isolated network for VPN container and Torrent's outbound traffic

- **Services**:
  - **Samba**: SMB file sharing on ports 137-139, 1445
  - **FileBrowser**: Web-based file manager on port 18080
  - **VPN** (Gluetun): WireGuard VPN to NordVPN (Canada)
  - **Torrent** (qBittorrent): Routes all traffic through VPN container, web UI on port 8080
  - **Nginx**: Reverse proxy for service routing
  - **Portainer**: Container management UI

- **Storage**: Services mount from `${STORAGE_BASE}` environment variable (ZFS pool)

### Target Kubernetes Architecture

- **Infrastructure**:
  - Single-node k3s cluster on Ubuntu 24.04.3 LTS
  - ZFS pool preserved from current setup
  - ZFS CSI driver (democratic-csi) for dynamic PersistentVolumes

- **GitOps**:
  - FluxCD reconciles cluster state from this Git repository
  - SOPS with age/GPG keys for secret encryption in Git
  - RenovateBot (planned) for automated dependency updates

- **Storage Strategy**:
  - OS SSD: k3s system components only
  - ZFS pool: All persistent application data via CSI-provisioned PVCs
  - Datasets mapped to StorageClasses for different workloads

- **Services** (planned):
  - File sharing: Samba/NFS, FileBrowser
  - Networking: Traefik ingress, VPN routing
  - Monitoring: Prometheus, Grafana, Loki + Promtail
  - Database: PostgreSQL StatefulSet backed by ZFS PVCs
  - Management: Portainer or equivalent

## Repository Structure

```
my-nas/
├── docker/                    # Current Docker Compose setup
│   ├── nas/                   # Samba + FileBrowser
│   ├── vpn/                   # Gluetun VPN container
│   ├── torrent/               # qBittorrent routing through VPN
│   ├── nginx/                 # Reverse proxy
│   ├── portainer/             # Management UI
│   └── .env.dev/.env.prod     # Environment variables (STORAGE_BASE, etc.)
├── infrastructure/            # Bootstrap automation (future)
│   ├── k3s-install/           # k3s installation scripts
│   ├── flux-bootstrap/        # FluxCD setup
│   └── sops/                  # Secret management helpers
├── clusters/                  # FluxCD + Kustomize overlays
│   ├── dev/                   # Local k3d cluster config
│   └── prod/                  # Production NAS k3s config
├── apps/                      # Application manifests (future)
│   ├── nas/                   # File services + PVCs
│   ├── networking/            # Ingress, VPN
│   ├── monitoring/            # Prometheus, Grafana, Loki
│   └── database/              # PostgreSQL
├── docs/                      # Operational documentation
│   ├── os-rebuild.md          # Ubuntu install + ZFS import guide
│   └── operations.md          # Runbooks, troubleshooting
├── PLAN.md                    # Migration roadmap and design decisions
└── *.sh                       # Helper scripts for Docker setup
```

## Development Workflow

### Working with Docker (Current)

1. Environment variables are in `docker/.env.dev` or `docker/.env.prod`
2. The `start.sh` script orchestrates VPN/Torrent setup and Nginx startup
3. VPN must start before Torrent to ensure proper network routing
4. Docker networks (`lan_net`, `vpn_net`) are created automatically by setup scripts

### Working with Kubernetes (Future)

1. **Local Testing**: Use k3d to create a local cluster matching production structure
2. **Manifest Development**: Write/update manifests in `apps/<service>/`
3. **Environment Overlays**: Reference apps from `clusters/dev/` or `clusters/prod/` with Kustomize
4. **Secret Management**: Encrypt secrets with SOPS before committing
5. **Deployment**: Push to Git → FluxCD reconciles automatically

### Testing Before Production

- Validate manifests with `kubectl apply --dry-run=client -k clusters/dev/`
- Test in local k3d cluster before pushing to main branch
- Use separate `clusters/dev/` overlays with hostPath or local storage (not ZFS)
- Production overlays in `clusters/prod/` reference ZFS CSI StorageClass

## Important Context

### Migration Status

The project is **in transition**. Docker setup is functional; Kubernetes infrastructure is planned but not yet implemented. See `PLAN.md` for:
- OS selection rationale (Ubuntu 24.04.3 LTS)
- ZFS pool preservation strategy
- Service catalog and requirements
- Open questions and next steps

### Critical Constraints

1. **ZFS Pool Preservation**: The 4-disk ZFS RAID array contains all data and must be preserved during OS migration
2. **Network Architecture**: VPN and Torrent require special network configuration (Torrent routes through VPN)
3. **Single-Node Cluster**: No HA/multi-node considerations; focus on simplicity and reliability
4. **GitOps-First**: This repository is the single source of truth; manual kubectl edits are discouraged in production

### Service Dependencies

- **Torrent → VPN**: Torrent container must route all traffic through VPN container
- **All Services → ZFS**: Application data lives on ZFS pool, not OS SSD
- **Ingress → Services**: Nginx (current) or Traefik (k3s) provides reverse proxy and routing

### Environment Variables

Current Docker setup requires:
- `STORAGE_BASE`: Base path for ZFS-mounted storage (e.g., `/mnt/pool0`)
- Defined in `docker/.env.dev` or `docker/.env.prod`

### Security Notes

- VPN credentials and WireGuard keys are in `docker/vpn/docker-compose.yml` (currently hardcoded)
- Future k3s setup will use SOPS-encrypted secrets in Git
- Network subnets are redacted in source files but defined in setup scripts

## GitOps Philosophy

The target architecture embraces GitOps principles:
- **Declarative**: All infrastructure and app config lives in Git
- **Versioned**: Every change is tracked with full audit trail
- **Automated**: FluxCD reconciles cluster to match repo state
- **Secure**: SOPS encrypts secrets at rest in Git
- **Testable**: Local k3d clusters validate changes before production

When editing Kubernetes manifests, always work through Git → FluxCD rather than direct `kubectl apply` commands.

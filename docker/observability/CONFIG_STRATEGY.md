# Configuration Strategy: Dev vs Prod

## Overview
The observability stack supports two modes for managing configuration files:

- **Dev Mode**: Bind mounts configs directly from source code (hot-reload on changes)
- **Prod Mode**: Bind mounts configs from persistent storage on RAID (immutable, rebuildable)

## How It Works

### Dev Mode (CONFIG_MODE=dev)
```bash
# Uses default paths in docker-compose (./loki-config.yml, ./grafana/provisioning, etc.)
docker compose --env-file ../../.env.dev -f docker-compose.yml up -d
```

**Behavior:**
- Configs mount from source: `./docker/observability/grafana/provisioning`
- Changes to source files reflect immediately in running containers
- Perfect for development and testing

### Prod Mode (CONFIG_MODE=prod)
```bash
# 1. Sync configs to persistent storage
./sync-configs.sh

# 2. Start services with prod env
docker compose --env-file ../../.env.prod -f docker-compose.yml up -d
```

**Behavior:**
- Configs mount from persistent storage: `${STORAGE_BASE}/configs/observability/...`
- Configs are decoupled from source code
- Containers can be rebuilt/destroyed without losing configs
- Updates require explicit sync: `./sync-configs.sh`

## File Structure

### Dev Environment
```
my-nas/
├── docker/observability/
│   ├── grafana/provisioning/      ← Mounted directly in dev
│   ├── loki-config.yml             ← Mounted directly in dev
│   ├── prometheus.yml              ← Mounted directly in dev
│   └── docker-compose.yml
└── docker/.env.dev                 (CONFIG_MODE=dev)
```

### Prod Environment
```
/mnt/storage/                       ← RAID array
├── configs/
│   └── observability/
│       ├── grafana/provisioning/   ← Mounted in prod
│       ├── loki-config.yml         ← Mounted in prod
│       └── prometheus.yml          ← Mounted in prod
├── qbittorrent/
├── nas/
└── portainer_data/
```

## Workflow

### Development
1. Edit configs in `my-nas/docker/observability/`
2. Restart affected containers to pick up changes
3. Test and iterate

### Deploying to Production
1. Update configs in Git
2. Pull latest on NAS
3. Run `./sync-configs.sh` to copy configs to persistent storage
4. Restart services with `--env-file docker/.env.prod`

### Updating Production Configs
```bash
# On NAS
cd /path/to/my-nas
git pull
./sync-configs.sh
docker compose --env-file docker/.env.prod -f docker/observability/docker-compose.yml restart
```

## Environment Variables

### .env.dev
```bash
STORAGE_BASE=/home/ubuntu/my-nas/nas-volumes
CONFIG_MODE=dev
# Config paths use defaults (relative paths in compose file)
```

### .env.prod
```bash
STORAGE_BASE=/mnt/storage
CONFIG_MODE=prod
LOKI_CONFIG=${STORAGE_BASE}/configs/observability/loki-config.yml
PROMTAIL_CONFIG=${STORAGE_BASE}/configs/observability/promtail-config.yml
PROMETHEUS_CONFIG=${STORAGE_BASE}/configs/observability/prometheus.yml
GRAFANA_PROVISIONING=${STORAGE_BASE}/configs/observability/grafana/provisioning
```

## Benefits

✅ **Dev**: Fast iteration, hot-reload configs  
✅ **Prod**: Immutable infrastructure, configs survive container rebuilds  
✅ **Single docker-compose.yml**: Same file works in both environments  
✅ **GitOps-ready**: Configs tracked in Git, synced to persistent storage  
✅ **RAID Protection**: Prod configs live on RAID array, safe from SSD failure

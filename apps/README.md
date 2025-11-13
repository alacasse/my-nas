# Applications

Store per-service manifests here (Helm values, Kustomize bases, etc.).

Proposed layout:
- `apps/nas/` – file services (Samba/FileBrowser replacement) and PVC definitions.
- `apps/networking/` – ingress controllers, VPN routing logic.
- `apps/monitoring/` – Prometheus, Grafana, Loki, exporters.
- `apps/database/` – PostgreSQL StatefulSet and backups.

Reference these directories from the environment overlays under `clusters/`.

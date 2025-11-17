# Repository Guidelines

## Project Structure & Module Organization
- `docker/` – compose stacks for NAS services: `nas/`, `nginx/`, `vpn/`, `torrent/`, `portainer/`; environment values live in `docker/.env.dev` and `.env.prod`.
- `apps/` – per-application Kubernetes manifests (values, Kustomize bases) to be referenced by overlays under `clusters/`.
- `clusters/` – FluxCD/Kustomize overlays per environment (`dev` for k3d, `prod` for k3s on the NAS).
- `infrastructure/` – install automation (Ubuntu autoinstall ISO builder, future k3s/Flux bootstrap).
- `docs/` – human-readable runbooks and rebuild notes.
- Root scripts: `start.sh`/`stop.sh`, `nginx-setup.sh`, `vpn-torrent-setup.sh`, etc. orchestrate Docker networks and services.

## Build, Test, and Development Commands
- Start everything for dev: `./start.sh` (brings up VPN + torrent, then nginx). Stop with `./stop.sh`.
- Bring up a single stack with compose, e.g. `docker compose --env-file docker/.env.dev -f docker/nas/docker-compose.yml up -d --build`.
- Validate autoinstall ISO locally: `cd infrastructure/os-install && ./build-autoinstall-iso.sh <ubuntu.iso>` then `./run-autoinstall-vm.sh artifacts/ubuntu-24.04.3-autoinstall.iso`.
- Check nginx or VPN networks: `docker network ls | grep lan_net` or `vpn_net`.

## Coding Style & Naming Conventions
- Bash scripts: prefer `#!/bin/bash`, `set -e` (or `set -euo pipefail`), lowercase snake_case variables, and comments for non-obvious network/volume choices.
- Compose/K8s manifests: indent with two spaces, keep service names short and aligned with directories (e.g., `vpn`, `torrent`, `nginx`).
- Environment files: key names are uppercase with underscores, keep secrets in `.env.prod` (never commit real secrets).

## Testing Guidelines
- For Docker: after changes, run `docker compose -f docker/<stack>/docker-compose.yml config` to confirm valid YAML; `docker compose ... ps` to ensure containers are healthy.
- For Kubernetes overlays (when present), run `kustomize build clusters/dev` before committing to catch manifest errors.
- Add smoke checks to scripts (e.g., verify networks exist before starts); no automated unit tests exist yet—document any manual validation in PRs.

## Commit & Pull Request Guidelines
- Recent history favors short, imperative summaries (`Got vpn + torrent to work`, `Nginx now runs`). Follow that style; keep bodies minimal and focused on what changed.
- Reference related scripts/manifests in the body when touching multiple stacks (e.g., `docker/vpn` and `docker/torrent`).
- PRs should include: purpose, impacted stacks (vpn/torrent/nginx/nas), manual test notes (compose config/ps output, screenshots if UI-facing like Portainer), and any secrets/ENV instructions. Link issues if available.

## Security & Configuration Tips
- Do not commit real credentials; keep `.env.prod` local. For now `.env.dev` can store non-sensitive defaults; SOPS/Flux secrets are planned under `infrastructure/sops/`.
- When routing torrent through VPN, ensure `vpn_net` exists before compose up (handled by `vpn-torrent-setup.sh`); avoid bypassing VPN by modifying container network modes.
- Before running autoinstall on hardware, replace placeholder password hashes in `infrastructure/os-install/autoinstall.yaml` and validate in the VM harness.

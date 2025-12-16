# Infrastructure Tooling

This folder hosts scripts/manifests for bootstrapping the NAS:

- `os-install/` – Ubuntu autoinstall config, ISO builder, and local VM test harness.
- `k3s-install/` – automation for bringing up k3s on Ubuntu 24.04.3 LTS (planned).
- `flux-bootstrap/` – instructions and manifests for FluxCD + SOPS keys (planned).
- `sops/` – helper scripts for key generation and secret encryption (planned).
- `install-docker.sh` – installs Docker Engine + Compose plugin, writes sane daemon defaults, and adds a service account to the docker group.
- `k3s-post-install.sh` – bootstraps Flux on the k3s cluster (dev or prod mode).
- `k3s-storage-setup.sh` – installs democratic-csi and sets up a `zfs-nfs` StorageClass on the NAS k3s cluster.

Populate these directories as the project evolves.

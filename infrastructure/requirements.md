# Production Installation Requirements

This document outlines the requirements for setting up the NAS environment on a production host.

## Operating System
- **OS**: Ubuntu Server 24.04 LTS (Noble Numbat) or compatible Linux distribution.
- **Architecture**: x86_64 (amd64).

## Docker Engine
- **Version**: Docker CE v27.x is **REQUIRED**.
  - **Reason**: Docker v29+ (API 1.44+) is currently incompatible with the Portainer client (API 1.41).
  - **Minimum API Version**: Must support API 1.41 or lower.
- **Installation**:
  - Do NOT use the `get.docker.com` script blindly, as it installs the latest version.
  - Pin the version during installation (e.g., `apt-get install docker-ce=5:27.5.1...`).

## Storage
- **Structure**:
  - A central storage directory (e.g., `/mnt/nas-data`) should be created.
  - Subdirectories for `nas`, `postgres_data`, `portainer_data`, etc., will be mapped here.
- **Permissions**:
  - The user running the containers (typically UID 1000) must have read/write access to these directories.

## Networking
- **Ports**:
  - 80 (Nginx Reverse Proxy)
  - 443 (Nginx SSL - future)
  - 9000 (Portainer)
  - 51820 (WireGuard VPN - if applicable)
- **DNS**:
  - Local DNS resolution (e.g., via `/etc/hosts` or a local DNS server) is required for `*.nas.test` domains to work.

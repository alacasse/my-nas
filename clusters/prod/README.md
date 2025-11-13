# Prod Cluster

Configuration for the NAS k3s cluster running on Ubuntu 24.04.3 LTS.

- Flux manifests here will reference the ZFS CSI StorageClass and production secrets (via SOPS).
- Use overlays tailored to the physical hardware (networking, storage, ingress).

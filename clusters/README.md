# Cluster Configuration

This directory holds FluxCD configuration and Kustomize overlays for each environment.

- `dev/`: targets a local k3d cluster for testing.
- `prod/`: targets the physical NAS k3s cluster.

Each subdirectory will eventually contain `flux-system/` manifests plus app references.

# Goal
Configure Traefik to output access logs to standard output (stdout) instead of a file.

# Reasoning
- **Log Rotation**: The user asked about log rotation. Traefik does not rotate file logs internally. Kubernetes/K3s automatically rotates logs captured from stdout/stderr.
- **Disk Usage**: Preventing the `/data/access.log` file from growing indefinitely.
- **Simplicity**: Removes the need for custom volume mounts and sidecar containers.

# Changes
## `clusters/dev/traefik-config.yaml`
- Remove `filePath` from access log configuration (reverts to stdout).
- Remove `deployment.additionalVolumes` and `deployment.additionalVolumeMounts` as they are no longer needed for logging.

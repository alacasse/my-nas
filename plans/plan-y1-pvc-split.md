# Plan: Split Multi-Document PVC YAML (Y1)

## Issue

The file `apps/nas/filebrowser/pvc.yaml` contains 2 PersistentVolumeClaim resources in a single file using YAML multi-document format (`---` separator). This is fragile and hard to maintain.

**Y1 Classification**: Multiple Documents Without Separation - A single file contains multiple Kubernetes resources separated by `---`, violating the one-resource-per-file best practice.

## Solution

Split into two separate files, one PVC per file.

## Files to Create/Modify

### 1. Create `apps/nas/filebrowser/pvc-config.yaml`

Contains only the `filebrowser-config` PVC (1Gi storage):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-config
  namespace: nas
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # storageClassName will be patched by environment overlays
```

### 2. Create `apps/nas/filebrowser/pvc-media.yaml`

Contains only the `filebrowser-media` PVC (500Gi storage):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-media
  namespace: nas
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi
  # storageClassName will be patched by environment overlays
```

### 3. Modify `apps/nas/filebrowser/kustomization.yaml`

Remove `pvc.yaml` from resources list and add the two new files:

```yaml
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - pvc-config.yaml      # NEW
  - pvc-media.yaml       # NEW
  # - pvc.yaml           # REMOVE
```

### 4. Delete `apps/nas/filebrowser/pvc.yaml`

Remove the original multi-document file after the new files are created and verified.

## Validation

After changes:

1. Run `kubectl kustomize apps/nas/filebrowser` to verify Kustomize builds correctly
2. Verify both PVCs are still referenced in the overlay
3. Check that `kubectl apply -k apps/nas/filebrowser` would succeed

## Priority

**P4** - Low priority, cosmetic/maintainability issue. This does not affect functionality but improves maintainability and follows Kubernetes best practices.

## Effort Estimate

- Creation of 2 new files: ~5 minutes
- Modification of kustomization.yaml: ~2 minutes
- Validation: ~5 minutes
- Total: ~12 minutes

# Filebrowser Pod Debug Report

## Issue Summary

The filebrowser pod `filebrowser-685bfb785f-zfjdp` (and replacement pods) is stuck in `Init:0/2` state, failing to start due to a missing ConfigMap.

## Root Cause Analysis

### Primary Issue: Missing ConfigMap `filebrowser-scripts`

**Evidence:**
- Pod events show: `MountVolume.SetUp failed for volume "scripts" : configmap "filebrowser-scripts" not found`
- The ConfigMap was never created in the `nas` namespace

### Contributing Factors

1. **Kustomize configMapGenerator Name Mismatch**
   - The kustomization at [`apps/nas/filebrowser/kustomization.yaml`](apps/nas/filebrowser/kustomization.yaml) uses `configMapGenerator` to create a ConfigMap with name `filebrowser-scripts`
   - However, kustomize adds a hash suffix to the generated name (e.g., `filebrowser-scripts-h5cft4c6h8`)
   - The deployment at [`apps/nas/filebrowser/deployment.yaml`](apps/nas/filebrowser/deployment.yaml) references `filebrowser-scripts` (static name) not the hashed name
   - This creates a mismatch where the generated ConfigMap name doesn't match the deployment's reference

2. **Deployment Process Gap**
   - When deploying with `kubectl apply -k clusters/dev/filebrowser/`, the process fails on PVC immutable field errors
   - The ConfigMap creation may have failed silently or been skipped due to these errors
   - The deployment script/Makefile doesn't properly handle the ConfigMap creation

3. **PVC Immutable Fields**
   - Existing PVCs (`filebrowser-config`, `filebrowser-media`) have `storageClassName` and `volumeName` set
   - The kustomize manifests don't include these fields, causing `kubectl apply` to fail with:
     ```
     spec: Forbidden: spec is immutable after creation except resources.requests
     ```

## Current State

- **ConfigMap:** `filebrowser-scripts-h5cft4c6h8` exists (created via kustomize output)
- **Deployment:** Updated to reference `filebrowser-scripts-h5cft4c6h8`
- **Pod:** Still failing because the ConfigMap is not being found despite the "unchanged" message

## Files Involved

| File | Purpose |
|------|---------|
| [`apps/nas/filebrowser/kustomization.yaml`](apps/nas/filebrowser/kustomization.yaml) | Kustomize config with `configMapGenerator` |
| [`apps/nas/filebrowser/deployment.yaml`](apps/nas/filebrowser/deployment.yaml) | Deployment referencing ConfigMap |
| [`apps/nas/filebrowser/scripts/init-config-perms.sh`](apps/nas/filebrowser/scripts/init-config-perms.sh) | Init container script for permissions |
| [`apps/nas/filebrowser/scripts/init-filebrowser.sh`](apps/nas/filebrowser/scripts/init-filebrowser.sh) | Init container script for database setup |
| [`clusters/dev/filebrowser/kustomization.yaml`](clusters/dev/filebrowser/kustomization.yaml) | Dev overlay |

## Proposed Fix Plan

### Option 1: Fix Kustomize Configuration (Recommended)

1. **Update kustomization.yaml** to disable name suffix hash:
   ```yaml
   configMapGenerator:
     - name: filebrowser-scripts
       options:
         disableNameSuffixHash: true
       files:
         - scripts/init-config-perms.sh
         - scripts/init-filebrowser.sh
   ```

2. **Ensure PVC manifests include existing fields** (storageClassName, volumeName) to prevent immutable field errors

3. **Update deployment** to use `name: filebrowser-scripts` (static name)

### Option 2: Update Deployment to Use Hashed Name

1. Keep the deployment's ConfigMap reference as `filebrowser-scripts-h5cft4c6h8`
2. Ensure kustomize builds are applied correctly

### Option 3: Manual ConfigMap Creation (Workaround)

Create the ConfigMap manually without kustomize:
```bash
kubectl create configmap filebrowser-scripts -n nas \
  --from-file=scripts/init-config-perms.sh=apps/nas/filebrowser/scripts/init-config-perms.sh \
  --from-file=scripts/init-filebrowser.sh=apps/nas/filebrowser/scripts/init-filebrowser.sh
```

## Immediate Actions Required

1. **Verify ConfigMap exists in correct namespace:**
   ```bash
   kubectl get configmap -n nas
   kubectl get configmap filebrowser-scripts-h5cft4c6h8 -n nas -o yaml
   ```

2. **If ConfigMap is missing**, recreate it:
   ```bash
   kubectl kustomize apps/nas/filebrowser/ | sed -n '1,/^---$/p' | kubectl apply -f -
   ```

3. **Delete stuck pod** to trigger recreation:
   ```bash
   kubectl delete pod filebrowser-7df95bffdc-vwdsc -n nas
   ```

4. **Monitor pod status:**
   ```bash
   kubectl get pods -n nas -l app=filebrowser -w
   ```

## Long-term Improvements

1. Add smoke tests to deployment scripts to verify ConfigMap creation
2. Document the kustomize `configMapGenerator` behavior and naming conventions
3. Add validation to CI/CD pipeline for k
4. Consider using `ustomize buildskubectl kustomize | kubectl apply` vs `kubectl apply -k` for better error handling

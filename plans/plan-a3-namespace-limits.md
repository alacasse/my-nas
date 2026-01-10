# Plan: Fix A3 - No ResourceQuota for `nas` Namespace

## Current State
- **Namespace:** `nas` defined in [`apps/base/namespaces.yaml`](apps/base/namespaces.yaml:21)
- **Current Apps:** Only `filebrowser` is deployed in the `nas` namespace
- **filebrowser Resources:**
  - requests: memory `64Mi`, cpu `10m`
  - limits: memory `256Mi`, cpu `200m`
- **Missing:** No `LimitRange` or `ResourceQuota` for the `nas` namespace

## Proposed Solution

### File Structure
Create two new manifest files in `apps/nas/`:
1. `apps/nas/limitrange.yaml` - Default resource limits for pods/containers
2. `apps/nas/resourcequota.yaml` - Namespace-wide resource quotas

### Option: Add to Kustomization
Update [`apps/nas/kustomization.yaml`](apps/nas/kustomization.yaml:4) to include both files.

### 1. LimitRange Design (`apps/nas/limitrange.yaml`)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: nas-limits
  namespace: nas
spec:
  limits:
  - type: Container
    default:
      memory: "256Mi"
      cpu: "200m"
    defaultRequest:
      memory: "64Mi"
      cpu: "10m"
    min:
      memory: "16Mi"
      cpu: "5m"
    max:
      memory: "1Gi"
      cpu: "1000m"
  - type: Pod
    min:
      memory: "16Mi"
      cpu: "5m"
    max:
      memory: "2Gi"
      cpu: "2000m"
```

**Rationale:**
- Default limits match filebrowser's explicit limits (256Mi memory, 200m CPU)
- Default requests match filebrowser's requests (64Mi memory, 10m CPU)
- Min values prevent resource starvation
- Max values prevent any single pod/container from consuming excessive resources
- Pod-level limits provide additional safeguard

### 2. ResourceQuota Design (`apps/nas/resourcequota.yaml`)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: nas-quota
  namespace: nas
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1000m"
    limits.memory: "1Gi"
    pods: "5"
    persistentvolumeclaims: "10"
```

**Rationale:**
- Total namespace CPU: 500m requests / 1000m limits (2x headroom for burst)
- Total namespace memory: 512Mi requests / 1Gi limits
- Pods: 5 (allows for future expansion beyond filebrowser)
- PVCs: 10 (accommodates current 2 PVCs + future storage needs)

### 3. Alignment with filebrowser

| Resource | filebrowser | LimitRange Default | ResourceQuota |
|----------|-------------|-------------------|---------------|
| CPU Request | 10m | 10m | 500m total |
| CPU Limit | 200m | 200m | 1000m total |
| Memory Request | 64Mi | 64Mi | 512Mi total |
| Memory Limit | 256Mi | 256Mi | 1Gi total |

**Compatibility:** ✅ filebrowser's existing resource configuration is fully compatible with the proposed limits. No changes to `deployment.yaml` are required.

## Implementation Steps

### Step 1: Create LimitRange manifest
```bash
# Create apps/nas/limitrange.yaml with the LimitRange resource
```

### Step 2: Create ResourceQuota manifest  
```bash
# Create apps/nas/resourcequota.yaml with the ResourceQuota resource
```

### Step 3: Update Kustomization
Update [`apps/nas/kustomization.yaml`](apps/nas/kustomization.yaml) to include:
```yaml
resources:
  - filebrowser
  - limitrange.yaml
  - resourcequota.yaml
```

### Step 4: Validate manifests
```bash
kubectl apply --dry-run=server -f apps/nas/limitrange.yaml
kubectl apply --dry-run=server -f apps/nas/resourcequota.yaml
```

### Step 5: Apply to cluster
```bash
kubectl apply -f apps/nas/limitrange.yaml
kubectl apply -f apps/nas/resourcequota.yaml
```

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `apps/nas/limitrange.yaml` | Create | LimitRange for nas namespace |
| `apps/nas/resourcequota.yaml` | Create | ResourceQuota for nas namespace |
| `apps/nas/kustomization.yaml` | Modify | Add new resources to Kustomization |

## Verification Commands

```bash
# Check LimitRange is applied
kubectl get limitrange -n nas

# Check ResourceQuota is applied
kubectl get resourcequota -n nas

# Check resource consumption against quota
kubectl describe resourcequota nas-quota -n nas
```

## Future Considerations

1. **Adding new apps to `nas` namespace:** The ResourceQuota will need to be adjusted if new apps require significant resources
2. **Horizontal scaling:** The pod limit (5) accommodates potential replicaset scaling for high availability
3. **Storage growth:** The PVC limit (10) allows for future storage expansion

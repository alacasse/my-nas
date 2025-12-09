# K3S Cluster Administration Guide

Quick reference for managing your NAS K3S cluster.

## Contexts & Connections

```bash
# See all available contexts
kubectl config get-contexts

# Switch to NAS cluster
kubectl config use-context nas-test

# Check current context
kubectl config current-context
```

---

## Essential Commands

### Cluster Status
```bash
kubectl get nodes                    # Node status
kubectl cluster-info                 # API server info
kubectl top nodes                    # Resource usage (if metrics-server installed)
```

### View Resources
```bash
kubectl get pods -A                  # All pods, all namespaces
kubectl get pods -n torrents         # Pods in specific namespace
kubectl get svc -A                   # All services
kubectl get ingress -A               # All ingress routes
kubectl get pvc -A                   # All storage claims
```

### Namespaces in Your Cluster
| Namespace | Purpose |
|-----------|---------|
| `dashboard` | Homepage |
| `management` | Portainer |
| `torrents` | qBittorrent |
| `observability` | Grafana, Prometheus, Loki |
| `flux-system` | FluxCD controllers |
| `kube-system` | K3S system components |

---

## Deploying & Managing Apps

### Deploy Changes
```bash
# After editing manifests:
./scripts/deploy-dev.sh

# Or directly:
kubectl apply -k clusters/dev/
```

### Restart a Deployment
```bash
kubectl rollout restart deployment/<name> -n <namespace>
# Example:
kubectl rollout restart deployment/homepage -n dashboard
```

### Delete & Redeploy
```bash
kubectl delete -k clusters/dev/    # Remove everything
kubectl apply -k clusters/dev/     # Redeploy
```

---

## Debugging

### View Pod Logs
```bash
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>     # Follow (live)
kubectl logs <pod-name> -n <namespace> --previous  # Previous crash
```

### Describe Resources (Events & Config)
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl describe deployment <name> -n <namespace>
kubectl describe ingress <name> -n <namespace>
```

### Execute Commands in Pod
```bash
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
kubectl exec -it <pod-name> -n <namespace> -- bash
```

### Common Issues
| Symptom | Command | What to Look For |
|---------|---------|------------------|
| Pod not starting | `kubectl describe pod <name> -n <ns>` | Events section at bottom |
| CrashLoopBackOff | `kubectl logs <pod> -n <ns> --previous` | Application error |
| ImagePullBackOff | `kubectl describe pod <name> -n <ns>` | Image name typo or registry auth |
| Pending PVC | `kubectl describe pvc <name> -n <ns>` | Storage class issues |

---

## Port Forwarding (Quick Access)

Access services without ingress:
```bash
kubectl port-forward svc/homepage -n dashboard 3000:3000
# Open http://localhost:3000

kubectl port-forward svc/portainer -n management 9000:9000
# Open http://localhost:9000

kubectl port-forward svc/qbittorrent -n torrents 8080:8080
# Open http://localhost:8080
```

---

## Ingress (Traefik)

Your cluster uses Traefik. Check routes:
```bash
kubectl get ingress -A
```

| URL | Service |
|-----|---------|
| `http://nas.test` | Homepage |
| `http://portainer.nas.test` | Portainer |
| `http://torrent.nas.test` | qBittorrent |

> **Note**: Add these to `/etc/hosts` pointing to VM IP (`10.120.238.107`)

---

## Storage

```bash
# View storage claims
kubectl get pvc -A

# View storage classes
kubectl get storageclass

# Check if PVC is bound
kubectl describe pvc <name> -n <namespace>
```

---

## Flux (GitOps)

```bash
# Check Flux status
kubectl get pods -n flux-system

# Force reconciliation (after git push in prod)
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Deploy all | `./scripts/deploy-dev.sh` |
| Get all pods | `kubectl get pods -A` |
| Watch pods | `kubectl get pods -A -w` |
| Pod logs | `kubectl logs <pod> -n <ns>` |
| Enter pod shell | `kubectl exec -it <pod> -n <ns> -- sh` |
| Restart app | `kubectl rollout restart deploy/<name> -n <ns>` |
| Delete all | `kubectl delete -k clusters/dev/` |
| Switch context | `kubectl config use-context nas-test` |

# FileBrowser App Critique

This document contains a comprehensive review of the YAML configuration and embedded code in the `apps/filebrowser/` directory.

---

## Table of Contents

1. [Critical Security Issues](#critical-security-issues)
2. [Architectural Problems](#architectural-problems)
3. [YAML Validity Issues](#yaml-validity-issues)
4. [Embedded Code Issues](#embedded-code-issues)
5. [Recommendations](#recommendations)

---

## Critical Security Issues

### 🔴 C1: Hardcoded Credentials in Plain Text

**File:** [`secret.yaml:8-9`](secret.yaml:8)

```yaml
stringData:
  FB_USERNAME: admin
  FB_PASSWORD: ChangeMe12345!
```

**Problem:**
- Credentials stored in plain text
- Committed to version control
- No encryption at rest

**Impact:** Security breach if repository is public or compromised

**Required Fix:** Migrate to SOPS/SealedSecrets per AGENTS.md guidelines

---

### 🔴 C2: Credentials Exposed via Command-Line Arguments

**File:** [`deployment.yaml:60`](deployment.yaml:60)

```bash
filebrowser --database "${DB_PATH}" users add "${FB_USERNAME}" "${FB_PASSWORD}" --perm.admin --scope "."
```

**Problem:**
- Credentials visible in:
  - `kubectl describe pod` output
  - `ps aux` inside container
  - Container logs

**Impact:** Credential exposure to anyone with cluster access

**Required Fix:** Use environment-based authentication or a secure credential injection method

---

## Architectural Problems

### 🟠 A1: Wrong Directory Structure

**File:** [`kustomization.yaml`](kustomization.yaml)

Per [`apps/README.md`](../../apps/README.md:6), filebrowser should be under `apps/nas/`, not `apps/filebrowser/`.

**Impact:** Inconsistent with project structure guidelines

**Required Fix:** Move to `apps/nas/filebrowser/`

---

### 🟠 A2: Shared PVC Ownership

**File:** [`pvc.yaml:17`](pvc.yaml:17)

```yaml
metadata:
  name: nas-media
```

**Problem:**
- `nas-media` PVC is defined in filebrowser's directory
- Presumed shared across multiple apps (qbittorrent, etc.)
- Single app shouldn't own shared resources

**Impact:** Naming conflicts, unclear ownership, maintenance issues

**Required Fix:** 
- Rename to `filebrowser-media` OR
- Move shared PVC to a dedicated location

---

### 🟠 A3: No ResourceQuota for `nas` Namespace

**File:** [`apps/base/namespaces.yaml`](../../apps/base/namespaces.yaml)

The `nas` namespace has no ResourceQuota or LimitRange defined.

**Impact:** Filebrowser can consume unbounded resources

**Required Fix:** Add LimitRange and ResourceQuota to `nas` namespace

---

### 🟠 A4: Image Tag `latest` is Anti-Pattern

**File:** [`deployment.yaml:39,89`](deployment.yaml:39)

```yaml
image: filebrowser/filebrowser:latest
```

**Problem:**
- No reproducible deployments
- Updates happen silently
- May cause unexpected behavior on restart

**Required Fix:** Pin to specific version (e.g., `v2.28.0`)

---

## YAML Validity Issues

### 🟡 Y1: Multiple Documents Without Separation

**File:** [`pvc.yaml`](pvc.yaml)

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
```

**Problem:**
- YAML multi-document format used
- Works with Kustomize but is fragile
- Hard to edit/maintain

**Recommended Fix:** Split into `filebrowser-config-pvc.yaml` and `nas-media-pvc.yaml`

---

### 🟡 Y2: Missing Liveness/Readiness Probes

**File:** [`deployment.yaml`](deployment.yaml)

No health checks defined for the filebrowser container.

**Impact:** If container hangs, Kubernetes won't restart it automatically

**Recommended Fix:** Add probes:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 30
readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
```

---

### 🟡 Y3: Service Type Not Explicit

**File:** [`service.yaml:6`](service.yaml:6)

```yaml
spec:
  # type is omitted - defaults to ClusterIP
```

**Recommended Fix:** Add explicit `type: ClusterIP`

---

## Embedded Code Issues

### 🟠 E1: Missing Error Handling in `init-config-perms`

**File:** [`deployment.yaml:26-30`](deployment.yaml:26)

```bash
if [ "$(stat -c %u /config)" != "1000" ]; then
  chown -R 1000:1000 /config || echo "WARN: unable to chown /config (root_squash?)"
fi
find /srv -maxdepth 1 -type d ! -user 1000 -exec chown 1000:1000 {} + 2>/tmp/chown.log || echo "WARN: ..."
```

**Problems:**
1. `|| echo "WARN"` swallows errors silently
2. No exit code propagation - init container always exits 0
3. Contradicts `set -e` on line 23

**Recommended Fix:**
```bash
set -euo pipefail

if [ "$(stat -c %u /config 2>/dev/null || echo 0)" != "1000" ]; then
  if ! chown -R 1000:1000 /config 2>&1; then
    echo "ERROR: Failed to chown /config" >&2
    exit 1
  fi
fi
```

---

### 🟠 E2: Inconsistent `set` Directive

**File:** [`deployment.yaml:23`](deployment.yaml:23) vs [`deployment.yaml:44`](deployment.yaml:44)

First init container:
```bash
set -e
```

Second init container:
```bash
set -euo pipefail
```

**Problem:** Inconsistent error handling between containers

**Recommended Fix:** Use `set -euo pipefail` in both containers

---

### 🟠 E3: Race Condition in DB Initialization

**File:** [`deployment.yaml:57-63`](deployment.yaml:57)

```bash
if [ ! -f "${DB_PATH}" ]; then
  filebrowser config init ...
  filebrowser users add ...
else
  echo "DB already exists; skipping user init..."
fi
```

**Problems:**
1. If PVC has corrupted DB, filebrowser fails silently
2. No DB schema version check
3. If secrets change, existing users can't authenticate but no error

**Recommended Fix:** Add schema version check and migration logic

---

### 🟠 E4: Hardcoded User ID 1000

**File:** [`deployment.yaml:26,27,30`](deployment.yaml:26)

```bash
if [ "$(stat -c %u /config)" != "1000" ]; then
  chown -R 1000:1000 /config
  find /srv ... -user 1000
```

**Problem:** Magic number not parameterized

**Recommended Fix:** Use environment variable or documented constant

---

### 🟡 E5: Poor Logging in Init Containers

**Problem:** Warnings go to stdout without structured format

**Recommended Fix:**
```bash
log() {
  echo "{\"level\":\"${LOG_LEVEL:-INFO}\",\"ts\":\"$(date -Iseconds)\",\"msg\":\"$1\"}"
}
log "WARN: unable to chown /config (root_squash?)"
```

---

### 🟡 E6: Indentation in HEREDOC

**File:** [`deployment.yaml:47-56`](deployment.yaml:47)

```bash
cat > "${CONFIG_PATH}" <<'EOF'
          {
            "port": 80,
```

**Problem:** JSON has 10 spaces of indentation, creating ugly output

**Recommended Fix:**
```bash
cat > "${CONFIG_PATH}" <<'EOF'
{
  "port": 80,
```

---

### 🟡 E7: Temporary File Not Cleaned Up

**File:** [`deployment.yaml:30`](deployment.yaml:30)

```bash
2>/tmp/chown.log || echo "WARN: unable to chown /srv (root_squash?)"
```

**Problem:** `/tmp/chown.log` is created but never checked or cleaned up

**Recommended Fix:** Remove or properly handle the log file

---

## Recommendations Summary

| Priority | Issue | Fix |
|----------|-------|-----|
| P0 | Plaintext secrets | Migrate to SOPS/SealedSecrets |
| P0 | CLI credential exposure | Use env-based auth |
| P0 | Shared PVC ownership | Move or rename `nas-media` |
| P1 | `latest` image tag | Pin to specific version |
| P1 | No health checks | Add liveness/readiness probes |
| P1 | DB race condition | Add schema migration logic |
| P2 | Directory structure | Move to `apps/nas/filebrowser/` |
| P2 | Missing ResourceQuota | Add LimitRange/ResourceQuota |
| P3 | Init container errors | Fix error handling, use `set -euo pipefail` |
| P3 | Hardcoded UID | Parameterize or use env var |
| P4 | Explicit Service type | Add `type: ClusterIP` |
| P4 | Split multi-doc YAML | Separate PVC files |

---

## Positive Aspects

- ✅ Good security context with non-root user (UID 1000)
- ✅ Graceful handling of root-squashed NFS volumes
- ✅ Proper volume mount separation (config vs data)
- ✅ Environment variable propagation
- ✅ Sensible resource requests/limits

---

## Unverified Claims

The agent who created this configuration **never ran**:
- `kubectl apply -k apps/filebrowser/` to validate YAML syntax
- `kubectl get ingress,pvc,deployment` to confirm resources apply
- Any actual test of filebrowser authentication flow
- Validation of PVC mounting across different storage backends

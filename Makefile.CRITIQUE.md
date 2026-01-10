# Makefile Critique

> Generated: 2026-01-10
> Status: Needs Fixing

## Executive Summary

The Makefile has **2 critical issues** that cause failures and **6 design problems** that reduce maintainability. Immediate action is required for the critical items; design improvements can be scheduled.

---

## Critical Issues (Will Fail)

### 1. `logs` Target Missing Default Value

**Location:** [Line 51](Makefile:51)

**Problem:**
```makefile
logs: ## Tail logs. Usage: make logs app=<app-label> (default: qbittorrent)
	@$(KUBECTL) logs -l app=$(app) --all-containers=true -f --tail=50
```

The help text claims a default of `qbittorrent`, but `$(app)` is undefined when not passed via command line. This results in:

```bash
$ make logs
kubectl logs -l app= --all-containers=true -f --tail=50
# Error: empty selector
```

**Impact:** Users cannot run `make logs` without specifying `app=`, contrary to the documented behavior.

**Fix Required:**
- Option A: Add default value in Makefile: `app ?= qbittorrent`
- Option B: Update help text to remove "(default: qbittorrent)"

---

### 2. `apply` Target Broken Path

**Location:** [Line 54](Makefile:54)

**Problem:**
```makefile
apply: ## Apply a specific app's manifests (Usage: make apply app=qbittorrent)
	@$(KUBECTL) apply -k clusters/dev/$(app)/
```

The command attempts to apply `clusters/dev/qbittorrent/`, but this directory doesn't exist. The project structure is:

```
apps/
  networking/qbittorrent/
  nas/filebrowser/
clusters/
  dev/
    kustomization.yaml  # references apps via kustomize
```

**Impact:** `make apply app=qbittorrent` fails with:
```
error: invalid path format: 'clusters/dev/qbittorrent/'
```

**Fix Required:**
Change to: `@$(KUBECTL) apply -k clusters/dev/` (like `up` target) or implement proper app selection via Kustomize.

---

## Design Problems (Maintainability)

### 3. Secrets Hardcoded in Makefile

**Location:** [Lines 30-31](Makefile:30-31)

```makefile
@$(SOPS) -d apps/networking/qbittorrent/secrets.enc.yaml | $(KUBECTL) apply -f -
@$(SOPS) -d apps/nas/filebrowser/secrets.enc.yaml | $(KUBECTL) apply -f -
```

**Problem:** Adding a new app with secrets requires modifying the Makefile. This is:
- Error-prone (easy to miss an app)
- Violates DRY principle
- Creates merge conflicts when multiple apps are added

**Recommendation:** Discover secrets automatically:
```makefile
SECRETS := $(wildcard apps/*/*/secrets.enc.yaml)
secret-up:
	@for secret in $(SECRETS); do \
		echo "Applying $$secret..."; \
		$(SOPS) -d $$secret | $(KUBECTL) apply -f -; \
	done
```

---

### 4. No Tool Validation

**Problem:** Running targets without required tools (`kubectl`, `sops`, `multipass`) produces confusing errors.

**Current behavior:**
```bash
$ make up
sops: command not found
# No clear error message
```

**Recommendation:** Add prerequisite checks:
```makefile
prereqs:
	@which kubectl >/dev/null || (echo "kubectl not found" && exit 1)
	@which sops >/dev/null || (echo "sops not found" && exit 1)

up: prereqs ## Apply manifests to the dev cluster
	...
```

---

### 5. Silent Failure on `down`

**Location:** [Line 37](Makefile:37)

```makefile
@-$(KUBECTL) delete -k clusters/dev/ --wait=true
```

**Problem:** The `-` prefix suppresses errors. If deletion fails, the user has no indication.

**Recommendation:** Remove `-` prefix or add explicit error handling:
```makefile
down: ## Delete resources defined in manifests
	@echo "Stopping services..."
	@$(KUBECTL) delete -k clusters/dev/ --wait=true || echo "Warning: Some resources could not be deleted"
```

---

### 6. No `app` Validation on `restart`

**Location:** [Line 40](Makefile:40)

```makefile
restart: ## Restart a specific service (Usage: make restart app=qbittorrent)
	@./scripts/restart-dev.sh $(app)
```

**Problem:** Empty `app` parameter passes through silently, potentially affecting wrong resources or causing script errors.

**Recommendation:** Add validation:
```makefile
restart: ## Restart a specific service (Usage: make restart app=qbittorrent)
	@if [ -z "$(app)" ]; then echo "Error: app parameter required" && exit 1; fi
	@./scripts/restart-dev.sh $(app)
```

---

### 7. `down` Doesn't Clean Namespaces

**Problem:** `kubectl delete -k clusters/dev/` removes most resources but leaves namespaces (which are in `apps/base/namespaces.yaml`, not in kustomize overlays).

**Impact:** Stale namespaces accumulate, causing confusion with `kubectl get namespaces`.

**Recommendation:** Add explicit namespace cleanup:
```makefile
down: ## Delete resources defined in manifests
	@echo "Stopping services..."
	@$(KUBECTL) delete -k clusters/dev/ --wait=true
	@echo "Deleting namespaces..."
	@$(KUBECTL) delete namespace nas networking monitoring 2>/dev/null || true
```

---

### 8. No `clean` or `destroy` Target

**Problem:** No way to fully reset the development environment (PVCs, CRDs, configmaps).

**Recommendation:** Add comprehensive cleanup:
```makefile
clean: down ## Full cleanup including persistent resources
	@echo "Cleaning persistent volumes..."
	@$(KUBECTL) delete pvc --all -A
	@echo "Cleaning configmaps..."
	@$(KUBECTL) delete configmap --all -A
```

---

## Minor Issues

| Issue | Location | Description |
|-------|----------|-------------|
| Missing newline at EOF | Line 54 | File should end with newline |
| Double newline | Lines 41-42 | Inconsistent spacing |
| Inconsistent help formatting | Lines 13-19 | Some targets have parenthetical notes, some don't |

---

## Priority Matrix

| Priority | Issue | Effort | Impact |
|----------|-------|--------|--------|
| P0 | `logs` default value | Low | Critical |
| P0 | `apply` broken path | Low | Critical |
| P1 | Secrets hardcoded | Medium | High |
| P1 | Tool validation | Low | Medium |
| P2 | Error handling | Low | Medium |
| P2 | `restart` validation | Low | Low |
| P3 | Namespace cleanup | Low | Low |
| P3 | `clean` target | Medium | Low |

---

## Files Referenced

- [`Makefile`](Makefile) - Main file under review
- [`apps/networking/qbittorrent/secrets.enc.yaml`](apps/networking/qbittorrent/secrets.enc.yaml) - qBittorrent secrets
- [`apps/nas/filebrowser/secrets.enc.yaml`](apps/nas/filebrowser/secrets.enc.yaml) - Filebrowser secrets
- [`scripts/restart-dev.sh`](scripts/restart-dev.sh) - Restart script
- [`clusters/dev/kustomization.yaml`](clusters/dev/kustomization.yaml) - Dev overlay configuration

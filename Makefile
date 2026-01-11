# Makefile for NAS K3S Development Environment

VM_NAME := nas-test
KUBECTL := kubectl
SOPS := sops
NAMESPACE := nas
PVC_NAMES :=
PV_NAME :=

.PHONY: help up down restart status logs shell apply deploy-app deploy-app-dry

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  up       - Start/Update all services (kubectl apply)"
	@echo "  down     - Stop all services (kubectl delete)"
	@echo "  restart  - Restart all services (down + up)"
	@echo "  status   - Show status of all pods"
	@echo "  shell    - Open a shell inside the VM"
	@echo "  logs     - Tail logs for a specific app (usage: make logs app=qbittorrent)"
	@echo "  apply    - Apply a specific app's manifests (Usage: make apply app=qbittorrent)"
	@echo "  deploy-app - Safer deploy with PV cleanup (Usage: make deploy-app app=<app> [pvc-names=\"pvc1 pvc2\"] [pv-name=<pv>] [namespace=<ns>])"
	@echo ""

	@echo "Examples:"
	@echo "  make logs app=qbittorrent    # Tail logs for qbittorrent"
	@echo "  make apply app=filebrowser   # Apply only filebrowser manifests"

up: ## Apply manifests to the dev cluster
	@echo "Creating namespaces..."
	@$(KUBECTL) apply -f apps/base/namespaces.yaml
	@echo "Applying secrets..."
	@$(SOPS) -d apps/networking/qbittorrent/secrets.enc.yaml | $(KUBECTL) apply -f -
	@$(SOPS) -d apps/nas/filebrowser/secrets.enc.yaml | $(KUBECTL) apply -f -
	@echo "Applying manifests from clusters/dev/..."
	@$(KUBECTL) apply -k clusters/dev/

down: ## Delete resources defined in manifests
	@echo "Stopping services..."
	@-$(KUBECTL) delete -k clusters/dev/ --wait=true

restart: ## Restart a specific service (Usage: make restart app=qbittorrent)
	@./scripts/restart-dev.sh $(app)


status: ## Show cluster status
	@echo "Cluster Status:"
	@$(KUBECTL) get pods -A -o wide

shell: ## Open SSH shell in the Multipass VM
	@multipass shell $(VM_NAME)

logs: ## Tail logs. Usage: make logs app=<app-label> (default: qbittorrent)
	@$(KUBECTL) logs -l app=$(app) --all-containers=true -f --tail=50

apply: ## Apply a specific app's manifests (Usage: make apply app=qbittorrent)
	@$(KUBECTL) apply -k apps/networking/$(app)/ || $(KUBECTL) apply -k apps/nas/$(app)/

app ?=
namespace ?= $(NAMESPACE)

deploy-app: ## Safer deploy with PV cleanup (Usage: make deploy-app app=<app> [pvc-names="pvc1 pvc2"] [pv-name=<pv>] [namespace=<ns>])
	@python3 scripts/deploy-app.py --app=$(app) --namespace=$(namespace) --pvc-names="$(PVC_NAMES)" --pv-name="$(PV_NAME)"

deploy-app-dry: ## Dry-run deploy to see what commands would run (Usage: make deploy-app-dry app=<app> ...)
	@python3 scripts/deploy-app.py --app=$(app) --namespace=$(namespace) --pvc-names="$(PVC_NAMES)" --pv-name="$(PV_NAME)" --dry-run --verbose

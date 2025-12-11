# Makefile for NAS K3S Development Environment

VM_NAME := nas-test
KUBECTL := kubectl

.PHONY: help up down restart status logs shell

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
	@echo ""

up: ## Apply manifests to the dev cluster
	@echo "Creating namespaces..."
	@$(KUBECTL) apply -f apps/base/namespaces.yaml
	@echo "Applying secrets..."
	@sops -d apps/qbittorrent/secrets.enc.yaml | $(KUBECTL) apply -f -
	@echo "Applying manifests from clusters/dev/..."
	@$(KUBECTL) apply -k clusters/dev/

down: ## Delete resources defined in manifests
	@echo "Stopping services..."
	@-$(KUBECTL) delete -k clusters/dev/ --wait=true

restart: down up ## Restart services (Stop + Start)

status: ## Show cluster status
	@echo "Cluster Status:"
	@$(KUBECTL) get pods -A -o wide

shell: ## Open SSH shell in the Multipass VM
	@multipass shell $(VM_NAME)

logs: ## Tail logs. Usage: make logs app=<app-label> (default: qbittorrent)
	@$(KUBECTL) logs -l app=$(or $(app),qbittorrent) --all-containers=true -f --tail=50

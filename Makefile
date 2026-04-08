# DevOps Learning Lab — Makefile
# Run 'make help' to see available targets.
#
# WHY Makefile over Taskfile?
# Make is the industry-standard build tool every DevOps practitioner encounters.
# Learning its quirks (tab sensitivity, phony targets, automatic variables) has
# high transferable value. go-task can be added later as a DX improvement.

# --- Configuration ---
CLUSTER_NAME  := devops-lab
KIND_CONFIG   := clusters/kind/kind-config.yaml
ARGOCD_NS     := argocd

# Helm chart references
ARGOCD_REPO   := https://argoproj.github.io/argo-helm
ARGOCD_CHART  := argo-cd
ARGOCD_VERSION := 7.8.13

# --- Colors ---
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m

.DEFAULT_GOAL := help

# ==============================================================================
# Help
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo "DevOps Learning Lab — Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick start:  make up      (create cluster + install ArgoCD + bootstrap)"
	@echo "Tear down:    make down    (destroy everything)"

# ==============================================================================
# Phase 1: Cluster Lifecycle
# ==============================================================================

.PHONY: cluster-create
cluster-create: ## Create the kind cluster (1 control-plane + 3 workers)
	@echo "$(GREEN)Creating kind cluster '$(CLUSTER_NAME)'...$(NC)"
	@echo ""
	@echo "WHY multi-node? A single-node cluster hides real-world scheduling,"
	@echo "node affinity, and failure concerns. Three workers lets you practice"
	@echo "pod anti-affinity, rolling updates, and node selection."
	@echo ""
	kind create cluster --config $(KIND_CONFIG) --wait 120s
	@echo ""
	@$(MAKE) --no-print-directory cluster-verify

.PHONY: cluster-destroy
cluster-destroy: ## Destroy the kind cluster
	@echo "$(RED)Destroying kind cluster '$(CLUSTER_NAME)'...$(NC)"
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)Cluster destroyed.$(NC)"

.PHONY: cluster-reset
cluster-reset: cluster-destroy cluster-create ## Destroy and recreate the cluster

.PHONY: cluster-verify
cluster-verify: ## Verify kubectl and helm connectivity
	@echo "$(YELLOW)--- Cluster Info ---$(NC)"
	@kubectl cluster-info --context kind-$(CLUSTER_NAME)
	@echo ""
	@echo "$(YELLOW)--- Nodes ---$(NC)"
	@kubectl get nodes --context kind-$(CLUSTER_NAME) -o wide
	@echo ""
	@echo "$(YELLOW)--- Node Labels (custom) ---$(NC)"
	@kubectl get nodes --context kind-$(CLUSTER_NAME) \
		-o custom-columns='NAME:.metadata.name,ROLES:.metadata.labels.node-role,TIER:.metadata.labels.tier,INGRESS-READY:.metadata.labels.ingress-ready'
	@echo ""
	@echo "$(YELLOW)--- Helm Version ---$(NC)"
	@helm version --short
	@echo ""
	@echo "$(GREEN)All checks passed. Cluster is ready.$(NC)"

.PHONY: cluster-status
cluster-status: ## Show cluster status and running pods
	@echo "$(YELLOW)--- Nodes ---$(NC)"
	@kubectl get nodes -o wide
	@echo ""
	@echo "$(YELLOW)--- All Pods (all namespaces) ---$(NC)"
	@kubectl get pods -A
	@echo ""
	@echo "$(YELLOW)--- Resource Usage ---$(NC)"
	@kubectl top nodes 2>/dev/null || echo "(Metrics server not installed yet — comes with Phase 3)"

.PHONY: preflight
preflight: ## Check for port conflicts before cluster creation
	@echo "$(YELLOW)Checking for port conflicts...$(NC)"
	@ss -tlnp 2>/dev/null | grep -E ':(80|443|30080|30443)\b' && \
		echo "$(RED)WARNING: Ports above are in use. Cluster creation may fail.$(NC)" || \
		echo "$(GREEN)No conflicts. Ports 80, 443, 30080, 30443 are available.$(NC)"

# ==============================================================================
# Phase 2: ArgoCD
# ==============================================================================

.PHONY: argocd-install
argocd-install: ## Install ArgoCD via Helm
	@echo "$(GREEN)Installing ArgoCD (chart version $(ARGOCD_VERSION))...$(NC)"
	@echo ""
	@echo "WHY Helm for the initial install? ArgoCD can't manage itself before it"
	@echo "exists. We bootstrap with Helm, then hand control to the app-of-apps"
	@echo "pattern so ArgoCD manages its own config from Git going forward."
	@echo ""
	helm repo add argo $(ARGOCD_REPO) --force-update
	kubectl create namespace $(ARGOCD_NS) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argocd argo/$(ARGOCD_CHART) \
		--namespace $(ARGOCD_NS) \
		--version $(ARGOCD_VERSION) \
		--values platform/argocd/values.yaml \
		--wait --timeout 5m
	@echo ""
	@echo "$(GREEN)ArgoCD installed.$(NC)"
	@$(MAKE) --no-print-directory argocd-password

.PHONY: argocd-password
argocd-password: ## Retrieve the ArgoCD admin password
	@echo "$(YELLOW)ArgoCD admin password:$(NC)"
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo "" || \
		echo "$(RED)Secret not found. ArgoCD may not be installed yet.$(NC)"

.PHONY: argocd-portforward
argocd-portforward: ## Port-forward ArgoCD UI to localhost:8080
	@echo "$(GREEN)ArgoCD UI will be available at: https://localhost:8080$(NC)"
	@echo "$(YELLOW)Username: admin$(NC)"
	@echo -n "$(YELLOW)Password: $(NC)" && \
		kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d && echo ""
	@echo ""
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NS) 8080:443

.PHONY: argocd-bootstrap
argocd-bootstrap: ## Apply the root app-of-apps Application
	@echo "$(GREEN)Bootstrapping app-of-apps pattern...$(NC)"
	@echo ""
	@echo "WHY app-of-apps? This single Application CR tells ArgoCD to watch a"
	@echo "directory of Application CRs. Adding a new tool = adding a YAML file"
	@echo "to that directory. No kubectl apply, no Helm commands — just Git."
	@echo ""
	kubectl apply -f platform/app-of-apps/root-app.yaml
	@echo ""
	@echo "$(GREEN)Root Application applied. ArgoCD now manages all apps from Git.$(NC)"

# ==============================================================================
# Phase 3: Observability
# ==============================================================================

.PHONY: grafana
grafana: ## Port-forward Grafana to localhost:3000
	@echo "$(GREEN)Grafana available at: http://localhost:3000$(NC)"
	@echo "$(YELLOW)Username: admin | Password: devops-lab$(NC)"
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

.PHONY: prometheus
prometheus: ## Port-forward Prometheus to localhost:9090
	@echo "$(GREEN)Prometheus available at: http://localhost:9090$(NC)"
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# ==============================================================================
# Convenience targets
# ==============================================================================

.PHONY: up
up: cluster-create argocd-install argocd-bootstrap ## Full setup: cluster + ArgoCD + app-of-apps

.PHONY: down
down: cluster-destroy ## Full teardown

.PHONY: reset
reset: down up ## Full reset: destroy and recreate everything

# DevOps Learning Lab

## Project Overview
Local DevOps learning lab that bootstraps a full platform engineering stack on a kind
(Kubernetes-in-Docker) cluster. Built incrementally in 7 phases, each a working milestone.
Uses ArgoCD for GitOps — all tools are deployed as ArgoCD Applications.

## Architecture
- **Runtime:** kind cluster (1 control-plane + 3 workers) on WSL2, 94GB RAM
- **GitOps:** ArgoCD manages all deployments via Application CRDs (app-of-apps pattern)
- **Helm primary:** Third-party tools installed via official Helm charts with values overrides
- **Kustomize:** Used only for composing ArgoCD Application CRDs (our own manifests)

## Directory Structure
- `clusters/kind/` — kind cluster configuration
- `platform/<tool>/` — Helm values and config for each platform tool
- `platform/app-of-apps/apps/` — ArgoCD Application CRDs (one per tool)
- `platform/app-of-apps/root-app.yaml` — The ONE manually-applied root Application
- `apps/` — Demo application workloads (bookinfo, sample-app, rollout-demo)
- `examples/` — Example configs for Istio, chaos experiments, rollouts, workflows
- `terraform/` — Terraform configs targeting LocalStack (AWS mock)
- `ansible/` — Ansible playbooks targeting localhost
- `docs/` — Per-phase documentation and AI workflow guide

## Phases
1. **Foundation** — kind cluster, Makefile, pre-commit hooks
2. **GitOps Core** — ArgoCD (self-managing), GitHub Actions linting
3. **Observability** — kube-prometheus-stack, Grafana Tempo, OTel Collector
4. **Networking** — Istio service mesh (mTLS, traffic splitting, ingress)
5. **Security** — Vault, OPA/Gatekeeper, Trivy, Falco
6. **IaC** — Terraform + Crossplane (both targeting LocalStack), Ansible
7. **Advanced** — Argo Workflows, Argo Rollouts, Backstage, Chaos Mesh

## Key Commands
```
make help              # Show all available targets
make up                # Full setup: cluster + ArgoCD + bootstrap
make down              # Destroy everything
make reset             # Destroy + recreate
make cluster-verify    # Check cluster health and node labels
make cluster-status    # Show all pods across all namespaces
make argocd-portforward # Access ArgoCD UI at https://localhost:8080
make preflight         # Check for port conflicts before cluster creation
```

## MCP Servers (configured in .mcp.json)
- **terraform** — Terraform registry lookups and provider documentation
- **kubernetes** — Direct kubectl access from Claude Code (reads ~/.kube/config)
- **github** — PR/issue management (requires GITHUB_PAT env var)
- **argocd** — Application management and sync status (requires ARGOCD_TOKEN env var)

## Conventions
- All Kubernetes manifests use YAML (not JSON)
- Helm values files live in `platform/<tool>/values.yaml`
- ArgoCD Applications include `phase` and `component` labels
- Namespaces created by ArgoCD syncPolicy (`CreateNamespace=true`)
- Resource requests and limits are always specified for platform tools

## Important Notes
- Repo is **public** — ArgoCD pulls from Git without credentials
- kind cluster exposes ports 80/443 (Istio ingress) and 30080/30443 (ArgoCD NodePort)
- ArgoCD runs with `--insecure` (no TLS) — TLS termination comes with Istio in Phase 4
- Vault runs in **dev mode** (root token: "root") — never use this in production
- Istio sidecar injection requires namespace label: `istio-injection: enabled`
- Falco uses `modern_ebpf` driver on WSL2 kernel 6.6+ (may need fallback to `manual`)
- Phase 6 uses **LocalStack** (Docker) instead of real AWS for Terraform/Crossplane

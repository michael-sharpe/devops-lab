# DevOps Learning Lab

A local platform engineering stack on [kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker), built incrementally in 7 phases. Each phase is a working milestone you can commit, test, and learn from.

## Quick Start

```bash
# Check for port conflicts first
make preflight

# Create cluster + install ArgoCD + bootstrap app-of-apps
make up

# Verify everything is running
make cluster-status

# Access ArgoCD UI
make argocd-portforward
# Open https://localhost:8080 (user: admin, password: see output)
```

## The Stack

| Phase | Components | What You Learn |
|-------|-----------|---------------|
| **1. Foundation** | kind cluster, Makefile | Multi-node K8s, node labels, scheduling |
| **2. GitOps Core** | ArgoCD (app-of-apps) | GitOps, self-managing deployments |
| **3. Observability** | Prometheus, Grafana, Tempo, OTel | Metrics, tracing, dashboards |
| **4. Networking** | Istio service mesh | mTLS, traffic splitting, ingress |
| **5. Security** | Vault, Gatekeeper, Trivy, Falco | Secrets, policies, scanning, runtime security |
| **6. IaC** | Terraform, Crossplane, Ansible | Infrastructure as Code (3 approaches) |
| **7. Advanced** | Argo Workflows/Rollouts, Backstage, Chaos Mesh | CI pipelines, progressive delivery, chaos engineering |

## Prerequisites

- Docker (with sufficient resources)
- kind
- kubectl
- Helm
- make

## System Requirements

- **RAM:** 16GB minimum, 32GB+ recommended (all phases: ~25GB)
- **Disk:** 50GB+ free
- **OS:** Linux, macOS, or WSL2

## Directory Structure

```
clusters/kind/           # Kind cluster configuration
platform/                # Platform tools (Helm values + ArgoCD Applications)
  argocd/                #   ArgoCD configuration
  app-of-apps/           #   Root Application + per-tool Application CRs
  kube-prometheus-stack/  #   Prometheus + Grafana
  grafana-tempo/         #   Distributed tracing
  istio/                 #   Service mesh
  vault/                 #   Secrets management
  ...                    #   (one directory per tool)
apps/                    # Demo application workloads
examples/                # Example configs (Istio, chaos, rollouts)
terraform/               # Terraform configs (targeting LocalStack)
ansible/                 # Ansible playbooks
docs/                    # Per-phase documentation + AI workflow guide
```

## Claude Code Integration

This repo is set up for AI-assisted infrastructure management:

- **CLAUDE.md** — Project context loaded automatically by Claude Code
- **.mcp.json** — MCP servers for kubectl, ArgoCD, Terraform, GitHub
- **Custom commands** — `/deploy`, `/status`, `/debug`, `/validate`, `/teardown`, `/observe`

See [docs/ai-workflow.md](docs/ai-workflow.md) for details.

## Make Targets

```
make help              # Show all targets
make up                # Full setup (cluster + ArgoCD + bootstrap)
make down              # Full teardown
make reset             # Destroy + recreate
make cluster-create    # Create the kind cluster
make cluster-verify    # Check cluster health
make cluster-status    # Show all pods
make preflight         # Check for port conflicts
make argocd-install    # Install ArgoCD via Helm
make argocd-portforward # Access ArgoCD UI at localhost:8080
make argocd-bootstrap  # Apply the app-of-apps root Application
```

## Architecture Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Build tool | Makefile | Already installed, industry standard, high transferable value |
| Package manager | Helm (primary) | Official charts for all tools, values-override model is clear |
| Manifest composition | Kustomize (for ArgoCD CRs) | Good for composing our own Application manifests |
| Ingress/mesh | Istio | Teaches mTLS, traffic splitting, observability — more educational than Traefik |
| Tracing | Grafana Tempo | Native Grafana integration, simpler than Jaeger |
| Chaos engineering | Chaos Mesh | CNCF incubating, works on kind, clean CRD-based experiments |
| AWS mock | LocalStack | No AWS account needed, full S3/IAM/VPC API locally |

# AI Workflow — Using Claude Code with this Repo

## Overview

This repo integrates Claude Code as a first-class tool for infrastructure management.
Three mechanisms work together:

1. **CLAUDE.md** — Loaded automatically by Claude Code, provides project context so
   every session understands the repo structure, conventions, and architecture
2. **.mcp.json** — Connects Claude Code to live infrastructure via MCP servers
   (kubectl, ArgoCD, Terraform, GitHub)
3. **Custom slash commands** (`.claude/commands/`) — Task-oriented workflows for
   common operations

## Setup

### Prerequisites
- Docker running (for Terraform and GitHub MCP servers)
- Node.js/npx available (for Kubernetes and ArgoCD MCP servers)
- kind cluster created (`make up`)

### Environment variables
Set these in your shell or a `.env` file (gitignored):

```bash
# For the GitHub MCP server — create at https://github.com/settings/tokens
export GITHUB_PAT="ghp_your_token_here"

# For the ArgoCD MCP server — get from ArgoCD after install
# Option 1: Use the admin password
export ARGOCD_TOKEN="your_argocd_token"

# Option 2: Generate a token via ArgoCD CLI
# argocd login localhost:8080 --insecure --username admin --password $(make argocd-password)
# argocd account generate-token
```

## MCP Servers

### Terraform (`terraform`)
**When to use:** During Phase 6 work — looking up provider docs, checking module
interfaces, validating HCL patterns.

Example prompts:
- "What arguments does the aws_s3_bucket resource accept?"
- "Show me the latest version of the hashicorp/aws provider"
- "What's the difference between aws_iam_role and aws_iam_instance_profile?"

### Kubernetes (`kubernetes`)
**When to use:** Any time you need to interact with the cluster — checking pod status,
reading logs, describing resources, applying manifests.

Example prompts:
- "Show me all pods in the monitoring namespace"
- "Why is the prometheus pod in CrashLoopBackOff?"
- "Get the logs from the argocd-server pod"
- "Describe the ingress gateway service"

### GitHub (`github`)
**When to use:** Managing the repo — creating issues, PRs, checking CI status.

Example prompts:
- "Create an issue for adding cert-manager to Phase 4"
- "What's the status of the latest CI run?"
- "Create a PR for the Phase 3 observability work"

### ArgoCD (`argocd`)
**When to use:** Managing deployments — checking sync status, triggering syncs,
investigating failed deployments.

Example prompts:
- "What's the sync status of all ArgoCD applications?"
- "Sync the kube-prometheus-stack application"
- "Why is the vault application out of sync?"

## Custom Slash Commands

### /deploy \<phase-number\>
Deploys a specific phase to the cluster. Verifies the cluster is running, applies
ArgoCD Application CRs, and monitors sync status.

```
/deploy 3    # Deploy Phase 3 (Observability)
/deploy 5    # Deploy Phase 5 (Security)
```

### /status
Comprehensive health check of the entire environment: cluster nodes, ArgoCD
applications, namespaces, resource usage.

### /debug \<resource\>
Investigates a failing resource. Gathers logs, events, describe output, and
provides root cause analysis with suggested fixes.

```
/debug pod/prometheus-0 -n monitoring
/debug application/vault -n argocd
```

### /validate \<path\>
Validates YAML syntax, Helm values, ArgoCD Application structure, resource limits,
and label conventions for files in the given path.

```
/validate platform/kube-prometheus-stack/
/validate platform/app-of-apps/apps/
```

### /teardown \<phase-number\>
Removes a phase from the cluster by deleting its ArgoCD Applications (which
cascade-deletes all managed resources).

```
/teardown 7    # Remove Phase 7 (Advanced)
/teardown all  # Remove all phases (7→3, preserves ArgoCD)
```

### /observe \<service\>
Shows observability data for a service: RED metrics from Prometheus, traces from
Tempo, alerts from Grafana, security findings from Falco/Trivy.

```
/observe bookinfo
/observe sample-app
```

## Workflow Examples

### "I just pulled the repo and want to get started"
```
make up                  # Creates cluster, installs ArgoCD, bootstraps app-of-apps
/status                  # Verify everything is healthy
/deploy 3               # Deploy observability stack
```

### "Something is broken"
```
/status                  # See what's unhealthy
/debug <broken-thing>    # Investigate root cause
```

### "I want to add a new tool"
1. Create `platform/<tool>/values.yaml` with Helm overrides
2. Create `platform/app-of-apps/apps/<tool>.yaml` with the ArgoCD Application CR
3. `/validate platform/<tool>/` — check your work
4. Commit and push — ArgoCD auto-deploys
5. `/status` — verify it's healthy

### "I want to tear everything down and start fresh"
```
make reset               # Destroys cluster and recreates from scratch
```

## Tips

- **Start each Claude Code session with `/status`** to orient yourself
- **Use `/debug` before manual investigation** — it checks logs, events, and
  resource status systematically
- **The Kubernetes MCP server is the most useful** — it replaces most kubectl
  commands and provides structured output
- **ArgoCD MCP server is great for sync operations** — faster than port-forwarding
  to the UI
- **Always validate before committing** — `/validate` catches common mistakes
  like missing labels or inconsistent namespaces

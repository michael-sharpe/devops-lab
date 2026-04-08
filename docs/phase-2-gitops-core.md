# Phase 2 — GitOps Core

## What you're building
ArgoCD installed via Helm, managing itself through the app-of-apps pattern. After
this phase, every subsequent tool is deployed by committing YAML to Git — not by
running kubectl or helm commands.

## What you should learn

### GitOps principles
- **Git is the single source of truth** — the desired state of the cluster lives in
  Git, not in someone's head or a wiki
- **Declarative, not imperative** — you describe WHAT you want, not HOW to get there
- **Automated reconciliation** — ArgoCD continuously compares Git to the cluster and
  fixes any drift
- **Audit trail** — every change is a Git commit with author, timestamp, and diff

### ArgoCD concepts
- **Application** — a CRD that tells ArgoCD "watch this Git path/Helm chart and
  deploy it to this namespace"
- **Sync** — the process of making the cluster match Git
- **Health** — ArgoCD checks if deployed resources are actually healthy (pods running,
  services reachable)
- **Self-heal** — if someone manually changes a resource, ArgoCD reverts it
- **Prune** — if you delete a resource from Git, ArgoCD deletes it from the cluster

### App-of-apps pattern
The "app-of-apps" is a meta-pattern:
1. One "root" Application points to a directory of Application CRs
2. ArgoCD creates/manages all those child Applications
3. Each child Application deploys an actual tool

This means:
- Adding a tool = adding a YAML file to `platform/app-of-apps/apps/`
- Removing a tool = deleting that YAML file
- ArgoCD manages everything recursively

### Multi-source Applications
The ArgoCD self-management Application uses the `sources` (plural) field to combine:
- An upstream Helm chart (from the OCI/Helm repo)
- Our values file (from our Git repo)

The `ref: values` on the Git source creates a `$values` alias that the Helm source
references. This is the canonical way to use upstream charts with custom values.

### The bootstrap problem
ArgoCD can't manage itself before it exists. The bootstrap sequence is:
1. `helm install` creates ArgoCD (imperative, one-time)
2. `kubectl apply` creates the root Application (imperative, one-time)
3. ArgoCD discovers `apps/argocd.yaml` and takes over its own management
4. From now on, changes to `platform/argocd/values.yaml` in Git auto-apply

After step 3, you never run `helm upgrade` again.

## Prerequisites
- Phase 1 complete (cluster running)
- No additional tools needed

## Bootstrap sequence

```bash
# Option 1: Step by step
make cluster-create      # Phase 1 cluster
make argocd-install      # Initial Helm install
make argocd-password     # Get admin password
make argocd-portforward  # UI at https://localhost:8080
make argocd-bootstrap    # Apply root-app.yaml → ArgoCD takes over

# Option 2: All at once
make up
```

## Verification checklist

### 1. ArgoCD is running
```bash
kubectl get pods -n argocd
```
Expected: All pods in Running state (server, controller, repo-server, redis, etc.)

### 2. Access the ArgoCD UI
```bash
make argocd-portforward
```
Open https://localhost:8080 in your browser. Accept the self-signed certificate
warning. Login with username `admin` and the password from `make argocd-password`.

### 3. Root Application exists
In the ArgoCD UI, you should see a "root" Application that is Healthy and Synced.
It should show child applications being managed.

Via CLI:
```bash
kubectl get applications -n argocd
```

### 4. ArgoCD self-management works
The "argocd" Application should appear as a child of "root". It manages ArgoCD's
own installation.

### 5. Test the GitOps loop
Make a trivial change to `platform/argocd/values.yaml` (e.g., change the
reconciliation timeout), commit, and push. Within 30 seconds, ArgoCD should
detect the change and apply it.

### 6. Test self-healing
```bash
# Manually scale down the ArgoCD repo-server
kubectl scale deployment argocd-repo-server -n argocd --replicas=0

# Wait ~30 seconds, then check — ArgoCD should scale it back up
kubectl get pods -n argocd
```

### 7. GitHub Actions lint
Push to a branch and create a PR. The lint workflow should run and validate
YAML syntax, Helm templates, and yamllint rules.

## Files created in this phase
```
platform/argocd/values.yaml              # ArgoCD Helm value overrides
platform/app-of-apps/root-app.yaml       # The root app-of-apps Application
platform/app-of-apps/apps/argocd.yaml    # ArgoCD self-management Application
.github/workflows/lint.yaml              # GitHub Actions lint workflow
```

## Key concepts to understand before moving on
- [ ] What is GitOps and how does it differ from CI/CD-driven deployments?
- [ ] What is an ArgoCD Application and what fields does it require?
- [ ] How does the app-of-apps pattern work and why is it useful?
- [ ] What happens when Git and the cluster state diverge? (sync, self-heal, prune)
- [ ] How does ArgoCD's multi-source feature combine Helm charts with custom values?
- [ ] What is the bootstrap problem and how do we solve it?

# Phase 7 — Advanced

## What you're building
The capstone phase: CI pipelines (Argo Workflows), progressive delivery
(Argo Rollouts), a developer portal (Backstage), and chaos engineering
(Chaos Mesh). This is where all previous phases come together.

## What you should learn

### Argo Workflows
A Kubernetes-native workflow engine. Each step runs in its own container.
Workflows are defined as DAGs (directed acyclic graphs) or sequences.
- Replaces Jenkins/GitLab CI with declarative, K8s-native pipelines
- Steps can pass artifacts between each other
- Integrates with S3 for artifact storage, Prometheus for metrics

### Argo Rollouts — progressive delivery
Kubernetes Deployments only support rolling updates. Argo Rollouts adds:

**Canary:** Gradually shift traffic (20% → 40% → 60% → 80% → 100%).
At each step, query Prometheus for success rate. If it drops below 95%,
automatically roll back. Integrates with Istio for traffic splitting.

**Blue-Green:** Deploy the new version alongside the old one. Preview it
via a separate service. When ready, switch all traffic instantly. If
something's wrong, switch back.

**AnalysisTemplate:** Defines automated checks (Prometheus queries) that
run during rollouts. This closes the loop: deploy → observe → decide.

### Backstage — developer portal
A single UI for your entire platform:
- **Service Catalog:** what services exist, who owns them
- **Tech Docs:** documentation co-located with code
- **Kubernetes Plugin:** pod status, events, logs
- **ArgoCD Plugin:** deployment status, sync history

### Chaos Mesh — chaos engineering
Deliberately break things to find weaknesses:
- **PodChaos:** kill pods, test restart behavior
- **NetworkChaos:** inject latency, packet loss, partition
- **StressChaos:** overload CPU/memory, test resource limits
- **IOChaos:** simulate disk failures

## Components deployed

| Component | Namespace | Access |
|-----------|-----------|--------|
| Argo Workflows | argo | `kubectl port-forward -n argo svc/argo-workflows-server 2746:2746` |
| Argo Rollouts | argo-rollouts | `kubectl argo rollouts dashboard` or port-forward |
| Backstage | backstage | `kubectl port-forward -n backstage svc/backstage 7007:7007` |
| Chaos Mesh | chaos-mesh | `kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333` |

## Prerequisites
- All prior phases deployed (Phase 7 integrates across the full stack)
- `kubectl argo rollouts` plugin (optional, for CLI management):
  ```bash
  curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
  chmod +x kubectl-argo-rollouts-linux-amd64
  sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
  ```

## Verification checklist

### 1. All applications synced
```bash
kubectl get applications -n argocd | grep -E 'argo-|backstage|chaos'
```

### 2. Run a CI pipeline
```bash
kubectl apply -f examples/workflows/ci-pipeline.yaml -n argo

# Watch it execute
kubectl get workflows -n argo -w

# See the DAG in the UI
kubectl port-forward -n argo svc/argo-workflows-server 2746:2746
# Open http://localhost:2746
```

### 3. Try a canary rollout
```bash
# Create the demo namespace and rollout
kubectl apply -f apps/rollout-demo/namespace.yaml
kubectl apply -f examples/rollouts/analysis-template.yaml
kubectl apply -f examples/rollouts/canary-rollout.yaml

# Watch the rollout
kubectl argo rollouts get rollout demo-app -n demo -w

# Trigger a new version
kubectl argo rollouts set image demo-app -n demo app=nginx:1.26

# Watch traffic shift: 20% → 40% → 60% → 80% → 100%
```

### 4. Try a blue-green rollout
```bash
kubectl apply -f examples/rollouts/bluegreen-rollout.yaml

# Trigger a new version
kubectl argo rollouts set image demo-app-bg -n demo app=nginx:1.26

# Preview is available, but active still serves old version
# Manually promote when ready:
kubectl argo rollouts promote demo-app-bg -n demo
```

### 5. Run a chaos experiment
```bash
# Kill a bookinfo pod
kubectl apply -f examples/chaos/pod-kill.yaml
kubectl get pods -n bookinfo -w
# Pod dies and restarts — service stays available

# Inject network delay
kubectl apply -f examples/chaos/network-delay.yaml
# curl http://localhost:30080/productpage takes longer

# Clean up
kubectl delete -f examples/chaos/pod-kill.yaml
kubectl delete -f examples/chaos/network-delay.yaml
```

### 6. Access Chaos Mesh dashboard
```bash
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
# Open http://localhost:2333
```

### 7. Access Backstage portal
```bash
kubectl port-forward -n backstage svc/backstage 7007:7007
# Open http://localhost:7007
```
You should see the service catalog with bookinfo, observability stack,
Istio mesh, and security stack listed.

## The big picture — how everything connects

```
Developer pushes code
        │
        ▼
  GitHub Actions ──→ Lint YAML, Helm, policies
        │
        ▼
  ArgoCD detects change ──→ Syncs to cluster
        │
        ▼
  Argo Rollouts ──→ Canary deployment
        │                    │
        │              Istio splits traffic
        │                    │
        │           Prometheus monitors metrics
        │                    │
        │          AnalysisTemplate checks success rate
        │                    │
        │              ✓ Pass → promote
        │              ✗ Fail → rollback
        │
        ▼
  Running in production
        │
        ├── Prometheus scrapes metrics
        ├── OTel Collector gathers traces → Tempo
        ├── Grafana visualizes everything
        ├── Falco monitors runtime behavior
        ├── Trivy scans images for CVEs
        ├── Gatekeeper enforces policies
        └── Vault manages secrets
```

## Key concepts to understand
- [ ] How does a canary rollout work with Istio traffic splitting?
- [ ] What is an AnalysisTemplate and how does it automate rollback decisions?
- [ ] What is the difference between canary and blue-green deployments?
- [ ] How do Argo Workflows differ from GitHub Actions or Jenkins?
- [ ] What is chaos engineering and why should you do it in production?
- [ ] How does Backstage enable self-service for developers?

## Files in this phase
```
platform/argo-workflows/values.yaml                 # Argo Workflows config
platform/argo-rollouts/values.yaml                  # Argo Rollouts config
platform/chaos-mesh/values.yaml                     # Chaos Mesh config
platform/backstage/values.yaml                      # Backstage config
platform/backstage/catalog-info.yaml                # Service catalog entries
platform/app-of-apps/apps/argo-workflows.yaml       # ArgoCD Application
platform/app-of-apps/apps/argo-rollouts.yaml        # ArgoCD Application
platform/app-of-apps/apps/chaos-mesh.yaml           # ArgoCD Application
platform/app-of-apps/apps/backstage.yaml            # ArgoCD Application
apps/rollout-demo/namespace.yaml                    # Demo namespace
examples/workflows/ci-pipeline.yaml                 # CI pipeline workflow
examples/workflows/chaos-workflow.yaml              # Chaos test workflow
examples/rollouts/canary-rollout.yaml               # Canary deployment
examples/rollouts/bluegreen-rollout.yaml            # Blue-green deployment
examples/rollouts/analysis-template.yaml            # Prometheus success rate check
examples/chaos/pod-kill.yaml                        # Kill a pod
examples/chaos/network-delay.yaml                   # Inject 200ms latency
examples/chaos/cpu-stress.yaml                      # CPU stress test
```

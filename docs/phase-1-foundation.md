# Phase 1 — Foundation

## What you're building
A multi-node kind cluster with a Makefile for lifecycle management. This is the
foundation everything else runs on.

## What you should learn

### kind (Kubernetes-in-Docker)
- kind creates real Kubernetes clusters using Docker containers as nodes
- Each "node" is a Docker container running kubelet, containerd, and control-plane
  components (for control-plane nodes)
- `extraPortMappings` is required because Docker network isolation means cluster
  ports aren't accessible from the host by default
- The `ingress-ready=true` label on the control-plane node is a convention that
  ingress controllers use to select which node to bind to

### Node roles and labels
- Labels are key-value pairs attached to Kubernetes objects
- `nodeSelector` in pod specs uses labels to control scheduling
- Our cluster has three types of workers:
  - `node-role=infra` — for platform tools (monitoring, ingress, CI)
  - `node-role=app` — for application workloads
- In production, this separation prevents noisy-neighbor issues and allows
  independent scaling of platform vs application capacity

### Makefile
- Make uses **tabs** (not spaces) for indentation — this is a common gotcha
- `.PHONY` marks targets that don't produce files (all our targets)
- `$@` is the target name, `$<` is the first prerequisite (automatic variables)
- The `help` target uses grep/awk to auto-generate docs from `## comments`

## Prerequisites
All tools for Phase 1 are already installed:
- Docker 29.3.1
- kind 0.31.0
- kubectl 1.34.1
- Helm 3.20.0
- GNU Make 4.3

Optional (for pre-commit hooks):
```bash
pip3 install pre-commit
pre-commit install
```

## Verification checklist

### 1. Check for port conflicts
```bash
make preflight
```
Ensure ports 80, 443, 30080, 30443 are not in use.

### 2. Create the cluster
```bash
make cluster-create
```
Expected: 4 Docker containers running (1 control-plane + 3 workers).

### 3. Verify connectivity
```bash
make cluster-verify
```
Expected:
- kubectl connects to the cluster
- 4 nodes shown with correct labels
- Helm reports its version

### 4. Inspect the cluster
```bash
make cluster-status
```
Expected: System pods (coredns, etcd, kube-apiserver, kindnet, etc.) all Running.

### 5. Understand what's running
```bash
kubectl get pods -n kube-system
```
Each pod has a role:
- `etcd` — distributed key-value store for all cluster state
- `kube-apiserver` — the REST API that everything talks to
- `kube-controller-manager` — runs control loops (deployments, replicasets, etc.)
- `kube-scheduler` — decides which node a pod runs on
- `coredns` — cluster DNS (service discovery)
- `kindnet` — CNI plugin (pod networking)
- `kube-proxy` — implements Service networking (iptables/ipvs rules)

### 6. Verify node labels
```bash
kubectl get nodes --show-labels
```
Check that custom labels (`node-role`, `tier`, `ingress-ready`) are present.

### 7. Test teardown
```bash
make cluster-destroy
```
Expected: Clean deletion, all Docker containers removed.

### 8. Test full cycle
```bash
make cluster-reset
```
Expected: Destroy + create in one command.

### 9. Pre-commit hooks (optional)
```bash
pip3 install pre-commit
pre-commit install
pre-commit run --all-files
```
Expected: All hooks pass.

## Key concepts to understand before moving on
- [ ] What is a kind cluster and how does it differ from a production cluster?
- [ ] Why do we need `extraPortMappings` and what happens without them?
- [ ] What does each system pod in kube-system do?
- [ ] How do node labels enable workload placement?
- [ ] Why separate infrastructure and application nodes?

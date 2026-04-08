# Phase 5 — Security

## What you're building
Defense in depth: secrets management (Vault), policy enforcement (Gatekeeper),
image scanning (Trivy), and runtime threat detection (Falco).

## What you should learn

### Defense in depth
No single security tool covers everything. The four tools in this phase
address different layers:

| Layer | Tool | What it does |
|-------|------|-------------|
| Secrets | Vault | Encrypts, manages, and injects secrets into pods |
| Admission | Gatekeeper | Blocks non-compliant resources before they're created |
| Image | Trivy | Scans container images for known CVEs |
| Runtime | Falco | Monitors system calls for suspicious behavior |

### Vault concepts
- **Dev mode** — in-memory, auto-unseal, root token "root". Learning only.
- **K8s auth** — pods authenticate using their service account token
- **Policies** — define who can access which secret paths
- **Agent Injector** — sidecar that fetches secrets and writes to files

### Gatekeeper / OPA concepts
- **ConstraintTemplate** — defines a reusable policy in Rego (OPA's language)
- **Constraint** — instantiates a template with specific parameters
- **Admission webhook** — Gatekeeper intercepts K8s API requests and
  evaluates them against constraints. Non-compliant requests are rejected.

### Trivy Operator
- Runs as a controller, not a CLI tool
- Automatically scans images used by pods in the cluster
- Creates `VulnerabilityReport` CRDs with findings
- Reports severity: UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL

### Falco
- Uses eBPF to hook into the kernel's system call interface
- Rules detect suspicious behavior (not just known vulnerabilities)
- Example rules: terminal shell in container, sensitive file read,
  outbound connection to known-bad IP, privilege escalation
- Falcosidekick routes alerts to Prometheus/Grafana

## Components deployed

| Component | Namespace | Access | Purpose |
|-----------|-----------|--------|---------|
| Vault | vault | `kubectl port-forward -n vault svc/vault 8200:8200` | Secrets management |
| Gatekeeper | gatekeeper-system | Admission webhook (automatic) | Policy enforcement |
| Gatekeeper Policies | gatekeeper-system | Deployed from Git | 3 example policies |
| Trivy Operator | trivy-system | `kubectl get vulnerabilityreports -A` | Image scanning |
| Falco | falco | DaemonSet (automatic) | Runtime monitoring |

## Prerequisites
- Phase 2 complete (ArgoCD running)
- Phase 3 recommended (Falcosidekick sends metrics to Prometheus)

## Verification checklist

### 1. All applications are synced
```bash
kubectl get applications -n argocd | grep -E 'vault|gatekeeper|trivy|falco'
```

### 2. Vault is running
```bash
kubectl get pods -n vault
```
Expected: `vault-0` Running, `vault-agent-injector-*` Running.

### 3. Configure Vault K8s auth
```bash
kubectl exec -n vault vault-0 -- sh -c "$(cat platform/vault/config/k8s-auth-setup.sh)"
```

### 4. Test Vault secret injection
```bash
kubectl apply -f platform/vault/config/example-secret-injection.yaml
# Wait for the pod to start
kubectl exec vault-demo -- cat /vault/secrets/db-creds
```
Expected output:
```
username=demo-user
password=s3cur3-p@ssw0rd
```
Clean up: `kubectl delete -f platform/vault/config/example-secret-injection.yaml`

### 5. Access Vault UI
```bash
kubectl port-forward -n vault svc/vault 8200:8200
```
Open http://localhost:8200. Token: `root`

### 6. Gatekeeper policies are enforced
```bash
# This should be REJECTED (missing 'app' label):
kubectl run test --image=nginx -n default

# This should be REJECTED (no resource limits):
kubectl run test --image=nginx -n default --labels="app=test"

# This should work:
kubectl run test --image=nginx -n default --labels="app=test" \
  --requests='cpu=50m,memory=64Mi' --limits='cpu=100m,memory=128Mi'
kubectl delete pod test -n default
```

### 7. Check Gatekeeper audit results
```bash
kubectl get k8srequiredlabels -o yaml
kubectl get k8snoprivileged -o yaml
kubectl get k8srequireresourcelimits -o yaml
```
The `status.violations` field shows existing resources that violate each policy.

### 8. Check Trivy scan results
```bash
# List all vulnerability reports
kubectl get vulnerabilityreports -A

# See details for a specific image
kubectl get vulnerabilityreports -A -o wide
```

### 9. Falco is running (check for WSL2 compatibility)
```bash
kubectl get pods -n falco
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20
```
If Falco pods are in CrashLoopBackOff with eBPF errors, edit
`platform/falco/values.yaml` and change `driver.kind` to `manual`.

### 10. Trigger a Falco alert
```bash
# Shell into a running pod — Falco should detect this
kubectl exec -it -n bookinfo deploy/productpage-v1 -- /bin/sh
# Type 'exit' to leave
```
Check Falco logs:
```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=5
```

## Key concepts to understand before moving on
- [ ] What is defense in depth and why do you need multiple security layers?
- [ ] How does Vault's K8s auth method work? (service account → JWT → Vault token)
- [ ] What is a ConstraintTemplate vs a Constraint in Gatekeeper?
- [ ] What is an admission webhook and when does it run?
- [ ] What is the difference between image scanning (Trivy) and runtime monitoring (Falco)?
- [ ] Why should secrets NOT be stored in plain Kubernetes Secrets?

## Files in this phase
```
platform/vault/values.yaml                                    # Vault Helm config
platform/vault/config/k8s-auth-setup.sh                       # K8s auth setup script
platform/vault/config/example-secret-injection.yaml            # Demo pod with Vault injection
platform/gatekeeper/values.yaml                                # Gatekeeper Helm config
platform/gatekeeper/policies/require-labels/template.yaml      # ConstraintTemplate
platform/gatekeeper/policies/require-labels/constraint.yaml    # Constraint
platform/gatekeeper/policies/no-privileged/template.yaml       # ConstraintTemplate
platform/gatekeeper/policies/no-privileged/constraint.yaml     # Constraint
platform/gatekeeper/policies/require-resource-limits/template.yaml
platform/gatekeeper/policies/require-resource-limits/constraint.yaml
platform/trivy-operator/values.yaml                            # Trivy Helm config
platform/falco/values.yaml                                     # Falco Helm config
platform/app-of-apps/apps/vault.yaml                           # ArgoCD Application
platform/app-of-apps/apps/gatekeeper.yaml                      # ArgoCD Application
platform/app-of-apps/apps/gatekeeper-policies.yaml             # ArgoCD Application
platform/app-of-apps/apps/trivy-operator.yaml                  # ArgoCD Application
platform/app-of-apps/apps/falco.yaml                           # ArgoCD Application
```

## Troubleshooting

**Falco CrashLoopBackOff on WSL2:**
The modern_ebpf driver may not work on all WSL2 kernels. Check logs for
`driver` errors, then change `driver.kind` to `manual` in the values.

**Gatekeeper blocking system pods:**
The `exemptNamespaces` in values.yaml and `excludedNamespaces` in constraints
should prevent this. If system pods are blocked, add their namespace to both lists.

**Vault "permission denied" on secret read:**
The K8s auth role is bound to specific service accounts and namespaces.
Check that the pod's service account matches what's in the Vault role config.

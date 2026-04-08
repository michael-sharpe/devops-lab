# Phase 4 — Networking & Ingress (Istio)

## What you're building
An Istio service mesh with ingress gateway, mTLS between services, traffic
splitting, and fault injection — plus the Bookinfo demo app to experiment with.

## What you should learn

### Service mesh concepts
A service mesh moves networking concerns OUT of application code and INTO
infrastructure. Instead of every service implementing its own:
- TLS encryption → Istio handles mTLS automatically
- Retries and timeouts → configured via DestinationRule
- Load balancing → Envoy proxies distribute traffic
- Observability → sidecars emit metrics and traces for every request
- Traffic control → VirtualServices define routing rules

### Istio architecture
```
                    ┌─────────────┐
   External         │   Gateway   │  ← Envoy proxy at the edge
   Traffic ────────►│ (istio-sys) │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌─────────┐ ┌─────────┐ ┌─────────┐
         │ Pod + ☐  │ │ Pod + ☐  │ │ Pod + ☐  │  ☐ = Envoy sidecar
         │ sidecar  │ │ sidecar  │ │ sidecar  │
         └─────────┘ └─────────┘ └─────────┘
              ▲            ▲            ▲
              └────────────┼────────────┘
                           │
                    ┌──────┴──────┐
                    │   Istiod    │  ← Control plane: pushes config
                    │ (istio-sys) │     to all sidecars, manages certs
                    └─────────────┘
```

- **Istiod** — the control plane. Distributes routing config to sidecars,
  issues TLS certificates, validates configuration.
- **Envoy sidecar** — injected into every pod (when namespace has
  `istio-injection: enabled`). Intercepts all inbound/outbound traffic.
- **Gateway** — an Envoy proxy at the mesh edge. Routes external traffic in.

### Key Istio CRDs
- **Gateway** — defines which ports/hosts the ingress listens on
- **VirtualService** — routing rules (path-based, header-based, weighted)
- **DestinationRule** — defines subsets (versions) and connection policies
- **PeerAuthentication** — controls mTLS mode (PERMISSIVE or STRICT)

### Why sync waves matter here
Istio MUST be installed in order:
1. `istio-base` (wave 0) — installs CRDs
2. `istiod` (wave 1) — needs CRDs to exist
3. `istio-gateway` (wave 2) — needs istiod to configure its Envoy proxy
4. `bookinfo` (wave 3) — needs sidecar injection webhook from istiod

ArgoCD sync waves ensure the root app creates these Applications in order,
waiting for each to be Healthy before proceeding.

## Components deployed

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| istio-base | istio-system | CRDs (VirtualService, Gateway, etc.) |
| istiod | istio-system | Control plane |
| istio-gateway | istio-system | Ingress gateway (Envoy proxy) |
| bookinfo | bookinfo | Demo app (productpage, details, reviews, ratings) |

## Prerequisites
- Phase 2 complete (ArgoCD running)
- Phase 3 recommended (OTel Collector receives Istio traces)

## Deployment
Push to Git — ArgoCD deploys automatically via sync waves.

## Verification checklist

### 1. All four applications are synced
```bash
kubectl get applications -n argocd | grep -E 'istio|bookinfo'
```
Expected: `istio-base`, `istiod`, `istio-gateway`, `bookinfo` all Synced/Healthy.
This may take 2-3 minutes as sync waves execute sequentially.

### 2. Istio control plane is running
```bash
kubectl get pods -n istio-system
```
Expected: istiod pod Running, gateway pod Running.

### 3. Bookinfo pods have sidecars
```bash
kubectl get pods -n bookinfo
```
Expected: Each pod shows 2/2 READY (1 app container + 1 Envoy sidecar).
If pods show 1/1, sidecar injection isn't working — check the namespace label:
```bash
kubectl get namespace bookinfo --show-labels
```

### 4. Access Bookinfo via the gateway
```bash
# The gateway uses the kind port mappings (localhost:80 → gateway)
curl -s http://localhost/productpage | head -20
```
Or open http://localhost/productpage in your browser.

### 5. Verify traces flow to Tempo
After accessing the productpage a few times, open Grafana → Explore → Tempo.
Search for traces from `productpage.bookinfo`. You should see the full call
chain: productpage → details + reviews → ratings.

### 6. Try traffic splitting
```bash
kubectl apply -f examples/istio/traffic-split.yaml
```
Refresh /productpage repeatedly. ~80% of the time you'll see no stars (v1),
~20% you'll see black stars (v2).
```bash
# Revert
kubectl delete -f examples/istio/traffic-split.yaml
```

### 7. Try strict mTLS
```bash
kubectl apply -f examples/istio/mtls-strict.yaml
```
Services inside the bookinfo namespace now REQUIRE mTLS. A pod without a
sidecar cannot connect to them.
```bash
# Revert
kubectl delete -f examples/istio/mtls-strict.yaml
```

### 8. Try fault injection
```bash
kubectl apply -f examples/istio/fault-injection.yaml
```
Visit /productpage — the reviews section takes ~5s to load because Istio is
injecting a delay on the ratings service.
```bash
# Revert
kubectl delete -f examples/istio/fault-injection.yaml
```

## Key concepts to understand before moving on
- [ ] What is a service mesh and what problems does it solve?
- [ ] How does sidecar injection work? (mutating webhook, namespace label)
- [ ] What is mTLS and why is it important for zero-trust networking?
- [ ] How do VirtualService and DestinationRule work together for traffic splitting?
- [ ] What is fault injection and how does it differ from chaos engineering?
- [ ] How do Istio traces flow to Tempo via the OTel Collector?

## Files in this phase
```
platform/istio/base-values.yaml                   # Istio base CRD config
platform/istio/istiod-values.yaml                 # Control plane config
platform/istio/gateway-values.yaml                # Ingress gateway config
platform/app-of-apps/apps/istio-base.yaml         # ArgoCD App (wave 0)
platform/app-of-apps/apps/istiod.yaml             # ArgoCD App (wave 1)
platform/app-of-apps/apps/istio-gateway.yaml      # ArgoCD App (wave 2)
platform/app-of-apps/apps/bookinfo.yaml           # ArgoCD App (wave 3)
apps/bookinfo/namespace.yaml                      # Namespace with injection
apps/bookinfo/deployments.yaml                    # 6 Deployments + 4 Services
apps/bookinfo/gateway.yaml                        # Gateway + VirtualService
apps/bookinfo/destination-rules.yaml              # DestinationRules (subsets)
examples/istio/traffic-split.yaml                 # 80/20 canary example
examples/istio/mtls-strict.yaml                   # Strict mTLS example
examples/istio/fault-injection.yaml               # 5s delay injection example
```

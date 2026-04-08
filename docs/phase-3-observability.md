# Phase 3 — Observability

## What you're building
A full observability stack: metrics (Prometheus), visualization (Grafana),
distributed tracing (Tempo), and a telemetry pipeline (OpenTelemetry Collector).
All deployed as ArgoCD Applications — push to Git, ArgoCD deploys them.

## What you should learn

### The three pillars of observability
1. **Metrics** — numeric measurements over time (CPU usage, request rate, error count).
   Prometheus collects these by *scraping* HTTP endpoints that expose metrics in a
   specific format. You query metrics with PromQL.
2. **Traces** — the journey of a single request through multiple services. Each service
   adds a "span" to the trace. Tempo stores traces; you query them with TraceQL.
3. **Logs** — text records of events. Not set up in this phase (Loki would be the
   Grafana-native option), but the OTel Collector can handle logs too.

### Prometheus architecture
- **Prometheus server** — scrapes metrics from targets at regular intervals and stores
  them in a time-series database
- **ServiceMonitor** — a CRD that tells Prometheus "scrape this service's /metrics
  endpoint". The kube-prometheus-stack creates many of these automatically.
- **Recording rules** — pre-compute expensive queries and store results as new metrics
- **Alerting rules** — fire alerts when conditions are met (e.g., pod restart count > 5)
- **AlertManager** — receives alerts and routes them (email, Slack, PagerDuty)

### Grafana
- **Datasources** — where Grafana reads data from (Prometheus for metrics, Tempo for traces)
- **Dashboards** — visual panels showing metrics. The kube-prometheus-stack installs
  dozens of pre-built dashboards for cluster and workload monitoring.
- **Explore** — ad-hoc querying. Use this to write PromQL (metrics) or TraceQL (traces).

### OpenTelemetry Collector pipeline
The Collector has three stages:
```
Receivers → Processors → Exporters
```
- **Receivers** accept data in various formats (OTLP, Zipkin, Prometheus)
- **Processors** transform data (batch, filter, enrich with K8s metadata)
- **Exporters** send data to backends (Tempo for traces, Prometheus for metrics)

This decoupling is powerful: applications send to the Collector, and you can change
backends without touching application code.

### Why DaemonSet mode for the Collector
A DaemonSet runs one pod per node. Applications send telemetry to their local
Collector (same node), which means:
- Low latency (no cross-node network hops)
- Node-level metrics collection
- Failure isolation (one node's Collector going down doesn't affect others)

## Components deployed

| Component | Namespace | Access | Purpose |
|-----------|-----------|--------|---------|
| Prometheus | monitoring | port-forward 9090 | Metrics collection and storage |
| Grafana | monitoring | localhost:31000 (NodePort) | Visualization and dashboards |
| AlertManager | monitoring | port-forward 9093 | Alert routing |
| Tempo | tracing | internal only | Trace storage and query |
| OTel Collector | monitoring | internal (DaemonSet) | Telemetry pipeline |

## Prerequisites
- Phase 2 complete (ArgoCD running with app-of-apps)
- No additional tool installs needed

## Deployment
Phase 3 deploys automatically when you push the ArgoCD Application CRs to Git.
ArgoCD detects the new files in `platform/app-of-apps/apps/` and creates the
applications.

If you want to deploy manually:
```bash
kubectl apply -f platform/app-of-apps/apps/kube-prometheus-stack.yaml
kubectl apply -f platform/app-of-apps/apps/grafana-tempo.yaml
kubectl apply -f platform/app-of-apps/apps/otel-collector.yaml
```

## Verification checklist

### 1. ArgoCD shows all three applications
```bash
kubectl get applications -n argocd
```
Expected: `kube-prometheus-stack`, `grafana-tempo`, and `otel-collector` all
Healthy and Synced. The prometheus stack may take 3-5 minutes on first sync
due to CRD size.

### 2. All pods are running
```bash
kubectl get pods -n monitoring
kubectl get pods -n tracing
```
Expected:
- monitoring: prometheus-server, grafana, alertmanager, kube-state-metrics,
  node-exporter (one per node), otel-collector (one per node)
- tracing: tempo-0

### 3. Access Grafana
Open http://localhost:31000 in your browser.
- Username: `admin`
- Password: `devops-lab`

### 4. Explore pre-built dashboards
In Grafana, go to Dashboards. You should see dozens of pre-installed dashboards:
- "Kubernetes / Compute Resources / Cluster" — overall cluster health
- "Kubernetes / Compute Resources / Namespace (Pods)" — per-namespace breakdown
- "Node Exporter / Nodes" — host-level metrics per node

### 5. Verify Prometheus targets
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```
Open http://localhost:9090/targets. All targets should be UP.

### 6. Verify Tempo datasource in Grafana
In Grafana, go to Connections → Data sources. You should see:
- Prometheus (auto-configured)
- Tempo (configured via our values.yaml)

### 7. Test the OTel Collector pipeline
Send a test trace to verify the full pipeline works:
```bash
# Port-forward the OTel Collector's OTLP HTTP receiver
kubectl port-forward -n monitoring daemonset/otel-collector-opentelemetry-collector 4318:4318

# Send a test trace (in another terminal)
curl -X POST http://localhost:4318/v1/traces \
  -H 'Content-Type: application/json' \
  -d '{
    "resourceSpans": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "test-service"}}]},
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
          "spanId": "051581bf3cb55c13",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "1000000000",
          "endTimeUnixNano": "2000000000"
        }]
      }]
    }]
  }'
```
Then in Grafana → Explore → select Tempo datasource → search for the trace.

### 8. Check Collector health metrics
In Grafana → Explore → Prometheus, query:
```promql
otelcol_receiver_accepted_spans
```
This shows how many spans the Collector has received.

## Key concepts to understand before moving on
- [ ] What is the pull model (Prometheus scraping) vs push model (OTel Collector)?
- [ ] What is a ServiceMonitor and how does Prometheus discover scrape targets?
- [ ] How does the OTel Collector pipeline (receivers → processors → exporters) work?
- [ ] What is a trace, a span, and how do they relate?
- [ ] Why decouple applications from observability backends via the Collector?
- [ ] What are recording rules and alerting rules in Prometheus?

## Files in this phase
```
platform/kube-prometheus-stack/values.yaml               # Prometheus + Grafana config
platform/grafana-tempo/values.yaml                       # Tempo tracing config
platform/otel-collector/values.yaml                      # OTel Collector pipeline config
platform/app-of-apps/apps/kube-prometheus-stack.yaml     # ArgoCD Application
platform/app-of-apps/apps/grafana-tempo.yaml             # ArgoCD Application
platform/app-of-apps/apps/otel-collector.yaml            # ArgoCD Application
```

## Troubleshooting

**Prometheus stack stuck in Progressing:**
The kube-prometheus-stack CRDs are large. If sync takes >5 minutes:
```bash
kubectl get application kube-prometheus-stack -n argocd -o jsonpath='{.status.conditions}' | jq
```
Common fix: the `ServerSideApply=true` sync option is already set, which handles
the CRD size issue. If it persists, try a manual sync from the ArgoCD UI.

**OTel Collector pods in CrashLoopBackOff:**
Usually a config syntax error. Check logs:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

**Grafana shows "No data" for Tempo:**
Tempo needs to receive at least one trace before it appears. Use the test trace
command above, or wait until Istio (Phase 4) starts generating traces automatically.

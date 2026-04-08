Debug the issue with $ARGUMENTS.

Investigation steps:
1. Check the target resource status: `kubectl get` and `kubectl describe`
2. Check pod logs: `kubectl logs` (include previous container logs with --previous if restarting)
3. Check events in the relevant namespace: `kubectl get events --sort-by='.lastTimestamp'`
4. If this is an ArgoCD Application, check sync status and any sync errors
5. If this involves Istio, check proxy status and proxy config
6. If this involves Prometheus/Grafana, check the relevant ServiceMonitor and scrape targets
7. Check resource constraints: are pods being OOMKilled or evicted?

Use the Kubernetes MCP server to gather information. Provide a root cause analysis and suggested fix.

Show observability data for $ARGUMENTS.

Steps:
1. Query Prometheus for key metrics about the target workload:
   - Request rate, error rate, latency (RED metrics)
   - CPU and memory usage
   - Pod restart count
2. Check if traces exist in Tempo for the target service
3. Check Grafana dashboards for any alerts firing
4. If Falco is deployed, check for recent security alerts related to the target
5. If Trivy is deployed, show vulnerability report for the target's images

Use `kubectl port-forward` if needed to access Prometheus/Grafana/Tempo APIs.
Summarize findings in a structured format with actionable recommendations.

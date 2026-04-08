Check the status of the DevOps lab environment.

Report on:
1. **Cluster**: Is the kind cluster running? How many nodes? Node status and labels.
2. **ArgoCD**: List all ArgoCD Applications with their sync and health status.
3. **Namespaces**: List all namespaces and their pod counts.
4. **Phases deployed**: For each phase (1-7), check if its ArgoCD Applications exist.
5. **Resource usage**: Show cluster-wide CPU and memory utilization if metrics-server is available.

Use the Kubernetes MCP server for cluster queries and the ArgoCD MCP server for application status.

Format the output as a clear structured report.

Deploy phase $ARGUMENTS to the kind cluster.

Steps:
1. Verify the kind cluster is running: `kind get clusters`
2. Verify ArgoCD is healthy: `kubectl get pods -n argocd`
3. Identify all ArgoCD Application manifests in `platform/app-of-apps/apps/` that belong to the requested phase by checking their `phase` label
4. Apply any Application CRs that aren't already present in the cluster
5. Wait for each application to sync and become healthy
6. Report the status of all deployed applications

If any application fails to sync, investigate the sync error:
`kubectl get application -n argocd <app-name> -o jsonpath='{.status.conditions}'`

Use the ArgoCD MCP server to check application sync status if available.

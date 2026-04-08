Tear down phase $ARGUMENTS from the cluster.

Steps:
1. List all ArgoCD Applications with label `phase=$ARGUMENTS`
2. Delete each ArgoCD Application (cascade-deletes managed resources via the finalizer)
3. Wait for resources to be fully cleaned up
4. Verify the namespace is empty or deleted
5. Report completion

If $ARGUMENTS is "all", delete all phases in reverse order (7, 6, 5, 4, 3) to respect
dependencies. Phases 1-2 (cluster + ArgoCD) are not torn down — use `make down` for that.

Ask for confirmation before deleting.

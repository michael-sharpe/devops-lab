Validate the configuration for $ARGUMENTS.

Validation checks:
1. **YAML syntax**: Validate all YAML files in the target path are syntactically correct
2. **Helm template**: If helm values exist, verify they are valid YAML and contain expected keys
3. **ArgoCD Application**: Verify Application manifests have required fields (project, source, destination, syncPolicy)
4. **Resource limits**: Verify Deployments/StatefulSets specify resource requests and limits
5. **Labels**: Verify ArgoCD Applications have `phase` and `component` labels
6. **Namespace references**: Verify destination namespaces are consistent between Application manifests and helm values

Report any issues found with file paths and line numbers. Suggest fixes for each issue.

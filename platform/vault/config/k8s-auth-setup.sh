#!/bin/bash
# Configure Vault's Kubernetes auth method
#
# This script runs INSIDE the Vault pod to set up K8s authentication.
# After running this, pods with the correct service account can
# authenticate to Vault and read secrets.
#
# Usage:
#   kubectl exec -n vault vault-0 -- sh -c "$(cat platform/vault/config/k8s-auth-setup.sh)"

set -e

echo "=== Enabling Kubernetes auth method ==="
vault auth enable kubernetes 2>/dev/null || echo "Already enabled"

echo "=== Configuring Kubernetes auth ==="
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

echo "=== Creating a secret for demo purposes ==="
vault kv put secret/demo/db-creds \
  username="demo-user" \
  password="s3cur3-p@ssw0rd"

echo "=== Creating a policy that allows reading demo secrets ==="
vault policy write demo-app - <<POLICY
path "secret/data/demo/*" {
  capabilities = ["read"]
}
POLICY

echo "=== Creating a Kubernetes auth role ==="
# This role allows pods in the 'default' namespace with the 'default'
# service account to authenticate and get the 'demo-app' policy.
vault write auth/kubernetes/role/demo-app \
  bound_service_account_names=default \
  bound_service_account_namespaces=default,bookinfo \
  policies=demo-app \
  ttl=1h

echo ""
echo "=== Setup complete ==="
echo "Pods in the default/bookinfo namespace can now authenticate to Vault"
echo "and read secrets at secret/demo/*"
echo ""
echo "Test with:"
echo "  vault kv get secret/demo/db-creds"

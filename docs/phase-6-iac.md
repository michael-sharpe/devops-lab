# Phase 6 — IaC & Provisioning

## What you're building
Three approaches to Infrastructure as Code, side by side:
- **Terraform** — CLI-driven, state file, plan/apply workflow
- **Crossplane** — Kubernetes-native, CRD-driven, continuous reconciliation
- **Ansible** — Imperative/procedural, SSH-based (here targeting localhost)

All targeting LocalStack (local AWS mock) so no AWS account needed.

## What you should learn

### Terraform vs Crossplane — two IaC philosophies

| | Terraform | Crossplane |
|---|---|---|
| **Where it runs** | CLI on your laptop | Controller in the cluster |
| **How you define infra** | HCL files | Kubernetes CRDs (YAML) |
| **State** | File (local or remote S3) | Kubernetes etcd (built-in) |
| **Reconciliation** | Only on `terraform apply` | Continuous (like ArgoCD) |
| **When to use** | Standalone infra, multi-cloud | K8s-native teams, self-service platforms |

Neither is "better" — they solve different problems. Terraform is more mature
and widely adopted. Crossplane integrates naturally with Kubernetes workflows
and enables self-service platforms via XRDs.

### Crossplane concepts
- **Provider** — installs CRDs for a cloud provider (AWS, GCP, Azure)
- **ProviderConfig** — credentials and endpoint for the provider
- **Managed Resource** — a CRD representing a single cloud resource (S3 Bucket, IAM Role)
- **CompositeResourceDefinition (XRD)** — your simplified API (what developers see)
- **Composition** — maps the XRD to actual cloud resources (how it's implemented)
- **Claim** — what developers create to request infrastructure

### Ansible concepts
- **Inventory** — list of hosts to manage (here: just localhost)
- **Playbook** — YAML file defining tasks to execute
- **Task** — a single action (install package, run command, copy file)
- **Handler** — a task triggered by a notification (e.g., restart service after config change)
- **Idempotency** — running the same playbook twice produces the same result

## Prerequisites
- Phase 2 complete (ArgoCD for Crossplane deployment)
- Install tools:
  ```bash
  # Terraform
  # See: https://developer.hashicorp.com/terraform/install

  # Ansible
  pip3 install ansible

  # AWS CLI (optional, for verifying LocalStack resources)
  pip3 install awscli-local  # or: pip3 install awscli
  ```

## Components

| Component | Type | Location |
|-----------|------|----------|
| LocalStack | Docker container | `terraform/docker-compose.localstack.yml` |
| Terraform | CLI configs | `terraform/aws-free-tier/` |
| Crossplane | ArgoCD Application | `platform/crossplane/` |
| Ansible | Playbooks | `ansible/` |

## Setup and verification

### 1. Start LocalStack
```bash
make localstack-up

# Verify it's running
curl -s http://localhost:4566/_localstack/health | python3 -m json.tool
```

### 2. Terraform workflow
```bash
cd terraform/aws-free-tier

# Initialize — downloads the AWS provider
terraform init

# Plan — preview what will be created
terraform plan

# Apply — create the resources
terraform apply -auto-approve

# Verify resources exist in LocalStack
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 dynamodb list-tables
aws --endpoint-url=http://localhost:4566 iam list-roles

# Show outputs
terraform output

# Destroy — clean up
terraform destroy -auto-approve

cd ../..
```

### 3. Crossplane (deployed via ArgoCD)
Crossplane is installed automatically by ArgoCD. The AWS provider and
compositions need to be applied manually since they depend on Crossplane
being fully ready:

```bash
# Wait for Crossplane to be healthy
kubectl get pods -n crossplane-system

# Install the AWS providers
kubectl apply -f platform/crossplane/provider-aws.yaml
kubectl apply -f platform/crossplane/provider-aws-s3.yaml

# Wait for providers to be healthy (this downloads and installs CRDs)
kubectl get providers -w
# Wait until HEALTHY shows True for both

# Apply the provider config (points to LocalStack)
kubectl apply -f platform/crossplane/provider-config.yaml

# Apply the XRD and Composition
kubectl apply -f platform/crossplane/compositions/s3-bucket-xrd.yaml
kubectl apply -f platform/crossplane/compositions/s3-bucket-composition.yaml

# Create a bucket using the simplified API
kubectl apply -f platform/crossplane/compositions/example-bucket-claim.yaml

# Check the claim
kubectl get s3bucket
kubectl get bucket
```

### 4. Ansible playbooks
```bash
# Verify tools are installed
ansible-playbook -i ansible/inventory/local.yml ansible/playbooks/setup-tools.yml

# Configure the cluster
ansible-playbook -i ansible/inventory/local.yml ansible/playbooks/configure-cluster.yml
```

### 5. Compare the approaches
After running all three, reflect on the differences:
- Terraform: explicit plan/apply, state file, runs once
- Crossplane: create a YAML resource, controller reconciles continuously
- Ansible: procedural tasks, runs once, idempotent

## Key concepts to understand before moving on
- [ ] What is declarative vs imperative IaC?
- [ ] What is Terraform state and why is it important?
- [ ] How does Crossplane's continuous reconciliation differ from Terraform's apply-once model?
- [ ] What is a Crossplane XRD and why does it enable self-service platforms?
- [ ] What makes Ansible idempotent and why does that matter?
- [ ] When would you choose Terraform vs Crossplane vs Ansible?

## Files in this phase
```
terraform/docker-compose.localstack.yml              # LocalStack Docker setup
terraform/aws-free-tier/providers.tf                 # Terraform AWS provider (→ LocalStack)
terraform/aws-free-tier/variables.tf                 # Input variables
terraform/aws-free-tier/backend.tf                   # Local state backend
terraform/aws-free-tier/main.tf                      # S3 bucket, DynamoDB, IAM role
terraform/aws-free-tier/outputs.tf                   # Output values
platform/crossplane/values.yaml                      # Crossplane Helm config
platform/crossplane/provider-aws.yaml                # AWS provider for Crossplane
platform/crossplane/provider-aws-s3.yaml             # S3-specific provider
platform/crossplane/provider-config.yaml             # ProviderConfig → LocalStack
platform/crossplane/compositions/s3-bucket-xrd.yaml  # Simplified bucket API
platform/crossplane/compositions/s3-bucket-composition.yaml  # Implementation
platform/crossplane/compositions/example-bucket-claim.yaml   # Example claim
platform/app-of-apps/apps/crossplane.yaml            # ArgoCD Application
ansible/inventory/local.yml                          # Localhost inventory
ansible/playbooks/setup-tools.yml                    # Tool verification playbook
ansible/playbooks/configure-cluster.yml              # Cluster config playbook
```

## Troubleshooting

**LocalStack not reachable from Crossplane:**
Crossplane runs inside the kind cluster. LocalStack must be on the same
Docker network (`kind`). The docker-compose file joins this network.
Verify: `docker network inspect kind | grep localstack`

**Terraform "connection refused":**
Ensure LocalStack is running: `make localstack-up`
Check: `curl http://localhost:4566/_localstack/health`

**Crossplane provider stuck in "Installing":**
The provider downloads a large OCI image. Wait 2-3 minutes. Check:
`kubectl get providers` and `kubectl describe provider upbound-provider-family-aws`

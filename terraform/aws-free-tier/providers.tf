# Terraform provider configuration targeting LocalStack
#
# WHY Terraform?
# Terraform is the most widely used IaC tool. It uses a declarative
# language (HCL) to define infrastructure and maintains state to track
# what's been created. The plan/apply workflow lets you preview changes
# before making them.
#
# WHY LocalStack instead of real AWS?
# Same APIs, zero cost, no account needed. The Terraform code is
# identical — you just change the endpoint URL to point to real AWS
# when you're ready.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # LocalStack endpoint — all AWS services are served from port 4566
  endpoints {
    s3       = var.localstack_endpoint
    iam      = var.localstack_endpoint
    sts      = var.localstack_endpoint
    ec2      = var.localstack_endpoint
    dynamodb = var.localstack_endpoint
  }

  # LocalStack doesn't validate real credentials
  access_key = "test"
  secret_key = "test"

  # Skip AWS-specific validation that fails against LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Force path-style S3 URLs: http://localhost:4566/bucket-name
  # instead of http://bucket-name.localhost:4566 (which fails DNS lookup)
  s3_use_path_style = true

  default_tags {
    tags = {
      Project     = "devops-lab"
      Environment = "learning"
      ManagedBy   = "terraform"
    }
  }
}

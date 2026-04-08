# Terraform state backend
#
# WHY local backend?
# For learning, local state is simplest — no S3 bucket or DynamoDB lock
# table needed. In production, you'd use a remote backend (S3 + DynamoDB)
# so the team shares state and gets locking.
#
# To switch to remote state (when targeting real AWS):
#
# terraform {
#   backend "s3" {
#     bucket         = "devops-lab-terraform-state"
#     key            = "terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

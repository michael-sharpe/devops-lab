# Main Terraform configuration — AWS resources on LocalStack
#
# This creates a small set of AWS resources to demonstrate Terraform's
# plan/apply workflow. All resources target LocalStack so no real AWS
# account is needed.

# --- S3 Bucket ---
# WHY? S3 is the most fundamental AWS service. Understanding buckets,
# objects, policies, and versioning is essential AWS knowledge.
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts"

  tags = {
    Name    = "${var.project_name}-artifacts"
    Purpose = "Store build artifacts and logs"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- DynamoDB Table ---
# WHY? DynamoDB is commonly used for Terraform state locking and as
# a simple key-value store. Understanding on-demand vs provisioned
# capacity is important for cost management.
resource "aws_dynamodb_table" "app_state" {
  name         = "${var.project_name}-app-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name    = "${var.project_name}-app-state"
    Purpose = "Application state store"
  }
}

# --- IAM Role ---
# WHY? IAM is the foundation of AWS security. Understanding roles,
# policies, and trust relationships is critical for any AWS work.
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-app-role"

  # Trust policy: who can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-app-role"
    Purpose = "IAM role for application workloads"
  }
}

# Attach a policy to the role that allows S3 and DynamoDB access
resource "aws_iam_role_policy" "app_policy" {
  name = "${var.project_name}-app-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
        ]
        Resource = aws_dynamodb_table.app_state.arn
      }
    ]
  })
}

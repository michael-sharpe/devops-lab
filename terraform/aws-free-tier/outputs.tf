# Outputs — display key information after terraform apply

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.app_state.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.app_role.arn
}

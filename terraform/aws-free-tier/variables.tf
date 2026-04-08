# Variables for the AWS free tier Terraform configuration

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL. Set to real AWS endpoint to deploy to AWS."
  type        = string
  default     = "http://localhost:4566"
}

variable "project_name" {
  description = "Name used as prefix for all resources"
  type        = string
  default     = "devops-lab"
}

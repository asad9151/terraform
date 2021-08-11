output "tags" {
  description = "Tags used on resources for billing."
  sensitive   = false
  value       = local.common_tags
}

output "lambda_properties" {
  description = ""
  sensitive   = false
  value       = local.lambda_properties
}

output "account_id" {
  description = "The Account ID for POC or USSShared."
  sensitive   = false
  value       = local.account_id
}

output "lambda_concurrency" {
  description = "The number of lambda concurrency based on the environment of the function."
  sensitive   = false
  value       = local.concurrency
}

output "lambda_subnets" {
  description = "The subnet based on the environment."
  sensitive   = false
  value       = local.subnet
}

output "vpc_id" {
  description = "The VPC of the resources based on the environment."
  sensitive   = false
  value       = local.vpc
}

output "backend_s3_bucketName" {
  description = "The bucket name for the Terraform state file based on environment."
  sensitive   = false
  value       = local.backendS3BucketName
}

output "project" {
  description = "The project prefix."
  sensitive   = false
  value       = local.project
}

output "region" {
  description = "The AWS region for the resources based on the environment."
  sensitive   = false
  value       = local.region
}

output "mysql-subnets" {
  description = "The database subnet based on environment."
  sensitive   = false
  value       = local.mysql-subnets
}

output "conditional-resources" {
  description = "The map of flags to decide on creating resources based on environment."
  sensitive   = false
  value       = local.conditional_resources
}
output "central_account_id" {
  description = "Central account ID"
  value       = module.central_account.central_account_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the agent container"
  value       = module.central_account.ecr_repository_url
}

output "agent_prompts_secret_arn" {
  description = "ARN of the Secrets Manager secret containing agent prompts"
  value       = module.central_account.agent_prompts_secret_arn
}

output "audit_logs_bucket_name" {
  description = "Name of the S3 bucket for audit logs"
  value       = module.central_account.audit_logs_bucket_name
}

output "audit_logs_bucket_arn" {
  description = "ARN of the S3 bucket for audit logs"
  value       = module.central_account.audit_logs_bucket_arn
}

output "security_alerts_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = module.central_account.security_alerts_topic_arn
}

# These values are needed for the client environment terraform.tfvars
output "for_client_environment" {
  description = "Values to pass to the client environment"
  value       = module.central_account.for_client_environment
}

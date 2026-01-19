output "central_account_id" {
  description = "Central account ID"
  value       = module.central_account.central_account_id
}

output "agent_admin_role_arn" {
  description = "ARN of the IAM role for cross-account administration"
  value       = module.central_account.agent_admin_role_arn
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

# These values are needed for the client environment
output "for_client_environment" {
  description = "Values to pass to the client environment"
  value = {
    central_account_id        = module.central_account.central_account_id
    central_sns_topic_arn     = module.central_account.security_alerts_topic_arn
    central_audit_bucket_arn  = module.central_account.audit_logs_bucket_arn
    central_audit_bucket_name = module.central_account.audit_logs_bucket_name
  }
}

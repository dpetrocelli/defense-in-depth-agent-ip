output "central_account_id" {
  description = "Central account ID"
  value       = local.central_account_id
}

output "agent_admin_role_arn" {
  description = "ARN of the IAM role for cross-account administration"
  value       = aws_iam_role.agent_admin.arn
}

output "audit_logs_bucket_name" {
  description = "Name of the S3 bucket for audit logs"
  value       = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the S3 bucket for audit logs"
  value       = aws_s3_bucket.audit_logs.arn
}

output "security_alerts_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "system_prompt_secret_arn" {
  description = "ARN of the Secrets Manager secret for system prompt"
  value       = aws_secretsmanager_secret.system_prompt.arn
}

output "instruction_prompt_secret_arn" {
  description = "ARN of the Secrets Manager secret for instruction prompt"
  value       = aws_secretsmanager_secret.instruction_prompt.arn
}

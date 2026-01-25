output "central_account_id" {
  description = "Central account ID"
  value       = local.central_account_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the agent container"
  value       = aws_ecr_repository.agent.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.agent.arn
}

output "agent_prompts_secret_arn" {
  description = "ARN of the Secrets Manager secret containing agent prompts"
  value       = aws_secretsmanager_secret.agent_prompts.arn
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

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt secrets"
  value       = aws_kms_key.secrets.arn
}

# Gatekeeper outputs
output "gatekeeper_url" {
  description = "URL of the gatekeeper API"
  value       = "${aws_apigatewayv2_api.gatekeeper.api_endpoint}/get-prompts"
}

output "gatekeeper_signing_key" {
  description = "Signing key for gatekeeper authentication (embed in container image)"
  value       = random_password.signing_key.result
  sensitive   = true
}

# Output for client environment configuration
output "for_client_environment" {
  description = "Values to use in client environment terraform.tfvars"
  value = {
    ecr_repository_url        = aws_ecr_repository.agent.repository_url
    agent_prompts_secret_arn  = aws_secretsmanager_secret.agent_prompts.arn
    secrets_kms_key_arn       = aws_kms_key.secrets.arn
    central_sns_topic_arn     = aws_sns_topic.security_alerts.arn
    central_audit_bucket_arn  = aws_s3_bucket.audit_logs.arn
    central_audit_bucket_name = aws_s3_bucket.audit_logs.id
    gatekeeper_url            = "${aws_apigatewayv2_api.gatekeeper.api_endpoint}/get-prompts"
    central_event_bus_arn     = aws_cloudwatch_event_bus.central.arn
  }
}

# Output for container build (sensitive - use carefully)
output "for_container_build" {
  description = "Values needed to build the container (SENSITIVE - signing key)"
  value = {
    gatekeeper_url = "${aws_apigatewayv2_api.gatekeeper.api_endpoint}/get-prompts"
    signing_key    = random_password.signing_key.result
  }
  sensitive = true
}

# =============================================================================
# EventBridge Outputs
# =============================================================================

output "central_event_bus_arn" {
  description = "ARN of the central Event Bus for cross-account monitoring"
  value       = aws_cloudwatch_event_bus.central.arn
}

output "central_event_bus_name" {
  description = "Name of the central Event Bus"
  value       = aws_cloudwatch_event_bus.central.name
}

output "central_dashboard_url" {
  description = "URL to the central monitoring dashboard"
  value       = "https://${data.aws_region.current.id}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${var.project_name}-central-monitoring"
}

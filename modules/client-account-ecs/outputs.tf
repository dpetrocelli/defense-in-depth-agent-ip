# =============================================================================
# Outputs
# =============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "api_endpoint" {
  description = "Full API endpoint URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.agent.name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.agent.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.security_audit.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

# =============================================================================
# Security Summary
# =============================================================================

output "security_summary" {
  description = "Summary of security features enabled"
  value = {
    ecs_exec_disabled   = "YES - enable_execute_command = false"
    vpc_endpoints       = "YES - Bedrock, ECR, S3, CloudWatch, STS"
    waf_enabled         = "YES - Rate limiting + AWS Managed Rules"
    permission_boundary = "YES - Limits task role capabilities"
    preflight_check     = "YES - Blocks startup if Bedrock logging enabled"
    canary_tokens       = var.canary_webhook_url != "" ? "YES - Webhook configured" : "NO - Set canary_webhook_url to enable"

    monitoring_alerts = [
      "ECS Exec attempts",
      "Task definition changes",
      "Service modifications",
      "IAM role changes",
      "Bedrock logging enabled",
      "CloudTrail tampering",
      "Secrets access attempts",
      "Unauthorized role assumption"
    ]

    remaining_risks = [
      "Client CAN enable Bedrock logging (alert only, cannot block)",
      "Client CAN modify task definition (alert only, cannot block)",
      "Client CAN add sidecar containers (alert only, cannot block)"
    ]
  }
}

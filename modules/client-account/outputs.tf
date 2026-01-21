output "client_account_id" {
  description = "Client account ID"
  value       = local.client_account_id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.agent.name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.agent.arn
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.agent.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.agent.dns_name
}

output "alb_url" {
  description = "URL to access the agent API"
  value       = "http://${aws_lb.agent.dns_name}"
}

output "deployer_role_arn" {
  description = "ARN of the deployer role (for central account to assume)"
  value       = aws_iam_role.deployer.arn
}

output "invoke_api_command" {
  description = "Curl command to invoke the agent"
  value       = "curl -X POST http://${aws_lb.agent.dns_name}/invoke -H 'Content-Type: application/json' -d '{\"message\": \"Hello\", \"session_id\": \"test-001\"}'"
}

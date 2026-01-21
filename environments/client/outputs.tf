output "client_account_id" {
  description = "Client account ID"
  value       = module.client_account.client_account_id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.client_account.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = module.client_account.ecs_service_name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.client_account.alb_dns_name
}

output "alb_url" {
  description = "URL to access the agent API"
  value       = module.client_account.alb_url
}

output "invoke_api_command" {
  description = "Curl command to invoke the agent"
  value       = module.client_account.invoke_api_command
}

output "deployer_role_arn" {
  description = "ARN of the deployer role (for central account to assume)"
  value       = module.client_account.deployer_role_arn
}

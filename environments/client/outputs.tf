# =============================================================================
# Outputs - Lambda
# =============================================================================

output "lambda_api_url" {
  description = "Lambda API Gateway URL"
  value       = var.deployment_type == "lambda" || var.deployment_type == "both" ? module.lambda[0].api_gateway_url : null
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = var.deployment_type == "lambda" || var.deployment_type == "both" ? module.lambda[0].lambda_function_name : null
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = var.deployment_type == "lambda" || var.deployment_type == "both" ? module.lambda[0].lambda_function_arn : null
}

# =============================================================================
# Outputs - ECS
# =============================================================================

output "ecs_api_url" {
  description = "ECS ALB URL"
  value       = var.deployment_type == "ecs" || var.deployment_type == "both" ? module.ecs[0].api_endpoint : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.deployment_type == "ecs" || var.deployment_type == "both" ? module.ecs[0].ecs_cluster_name : null
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = var.deployment_type == "ecs" || var.deployment_type == "both" ? module.ecs[0].ecs_service_name : null
}

output "ecs_security_summary" {
  description = "ECS security features summary"
  value       = var.deployment_type == "ecs" || var.deployment_type == "both" ? module.ecs[0].security_summary : null
}

# =============================================================================
# Summary
# =============================================================================

output "deployment_type" {
  description = "Deployment type selected"
  value       = var.deployment_type
}

output "api_endpoints" {
  description = "All API endpoints"
  value = {
    lambda = var.deployment_type == "lambda" || var.deployment_type == "both" ? module.lambda[0].api_gateway_url : null
    ecs    = var.deployment_type == "ecs" || var.deployment_type == "both" ? module.ecs[0].api_endpoint : null
  }
}

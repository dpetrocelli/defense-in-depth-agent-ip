output "client_account_id" {
  description = "Client account ID"
  value       = module.client_account.client_account_id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.client_account.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.client_account.lambda_function_arn
}

output "api_gateway_url" {
  description = "URL to access the agent API"
  value       = module.client_account.api_gateway_url
}

output "invoke_api_command" {
  description = "Curl command to invoke the agent"
  value       = module.client_account.invoke_api_command
}

output "deployer_role_arn" {
  description = "ARN of the deployer role (for central account to assume)"
  value       = module.client_account.deployer_role_arn
}

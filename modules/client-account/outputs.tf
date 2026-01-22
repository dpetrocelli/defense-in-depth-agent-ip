output "client_account_id" {
  description = "Client account ID"
  value       = local.client_account_id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.agent.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.agent.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.agent.id
}

output "api_gateway_url" {
  description = "URL to access the agent API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "deployer_role_arn" {
  description = "ARN of the deployer role (for central account to assume)"
  value       = aws_iam_role.deployer.arn
}

output "invoke_api_command" {
  description = "Curl command to invoke the agent"
  value       = "curl -X POST ${aws_apigatewayv2_stage.default.invoke_url}/invoke -H 'Content-Type: application/json' -d '{\"message\": \"Hello\", \"session_id\": \"test-001\"}'"
}

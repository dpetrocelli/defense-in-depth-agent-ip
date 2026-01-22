# =============================================================================
# Lambda Function with Container Image
# =============================================================================
# Uses container image from central account ECR
# Scales to 0 automatically - pay only for invocations

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-agent"
  retention_in_days = 30

  tags = local.default_tags
}

# Lambda Function
resource "aws_lambda_function" "agent" {
  function_name = "${var.project_name}-agent"
  role          = aws_iam_role.lambda_execution.arn
  package_type  = "Image"
  image_uri     = "${var.ecr_repository_url}:${var.container_image_tag}"
  timeout       = 60
  memory_size   = var.lambda_memory

  # Environment variables
  environment {
    variables = {
      PROMPT_SECRET_ARN       = var.use_gatekeeper ? "" : var.agent_prompts_secret_arn
      MODEL_ID                = var.foundation_model
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/bootstrap"
      GATEKEEPER_URL          = var.gatekeeper_url
      USE_GATEKEEPER          = tostring(var.use_gatekeeper)
      ENABLE_RESPONSE_FILTER  = "true"
      API_KEY                 = var.api_key
    }
  }

  # Use ARM64 for better price/performance
  architectures = ["x86_64"]

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_execution
  ]

  tags = local.default_tags
}

# Lambda Function URL (alternative to API Gateway - simpler, cheaper)
# Uncomment if you prefer Function URL over API Gateway
# resource "aws_lambda_function_url" "agent" {
#   function_name      = aws_lambda_function.agent.function_name
#   authorization_type = "NONE"
# }

# =============================================================================
# API Gateway HTTP API
# =============================================================================
# HTTP API is cheaper and simpler than REST API

resource "aws_apigatewayv2_api" "agent" {
  name          = "${var.project_name}-agent"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Content-Type", "X-API-Key", "Authorization"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
    max_age       = 300
  }

  tags = local.default_tags
}

# Lambda integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.agent.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.agent.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Default route (catch-all)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.agent.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Health check route
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.agent.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Tools route
resource "aws_apigatewayv2_route" "tools" {
  api_id    = aws_apigatewayv2_api.agent.id
  route_key = "GET /tools"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Invoke route
resource "aws_apigatewayv2_route" "invoke" {
  api_id    = aws_apigatewayv2_api.agent.id
  route_key = "POST /invoke"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage (auto-deploy)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.agent.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  tags = local.default_tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-agent"
  retention_in_days = 30

  tags = local.default_tags
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agent.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.agent.execution_arn}/*/*"
}

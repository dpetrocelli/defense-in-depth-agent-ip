# =============================================================================
# Lambda Gatekeeper for Secure Prompt Delivery
# =============================================================================
# This Lambda validates requests using an embedded signing key before
# returning prompts. Only our legitimate container image can generate
# valid signatures.

# Generate a random signing key
resource "random_password" "signing_key" {
  length  = 64
  special = false
}

# Store signing key in Secrets Manager (for reference/rotation)
resource "aws_secretsmanager_secret" "signing_key" {
  name        = "${var.project_name}/gatekeeper-signing-key"
  description = "Signing key for gatekeeper authentication"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = local.default_tags
}

resource "aws_secretsmanager_secret_version" "signing_key" {
  secret_id     = aws_secretsmanager_secret.signing_key.id
  secret_string = random_password.signing_key.result
}

# =============================================================================
# Lambda Function
# =============================================================================

data "archive_file" "gatekeeper" {
  type        = "zip"
  source_file = "${path.module}/lambda/gatekeeper.py"
  output_path = "${path.module}/lambda/gatekeeper.zip"
}

resource "aws_lambda_function" "gatekeeper" {
  filename         = data.archive_file.gatekeeper.output_path
  function_name    = "${var.project_name}-gatekeeper"
  role             = aws_iam_role.gatekeeper_lambda.arn
  handler          = "gatekeeper.lambda_handler"
  source_code_hash = data.archive_file.gatekeeper.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      SIGNING_KEY             = random_password.signing_key.result
      PROMPT_SECRET_ARN       = aws_secretsmanager_secret.agent_prompts.arn
      ALLOWED_CLIENT_ACCOUNTS = var.client_account_id
    }
  }

  tags = local.default_tags
}

# Lambda IAM Role
resource "aws_iam_role" "gatekeeper_lambda" {
  name = "${var.project_name}-gatekeeper-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "gatekeeper_lambda" {
  name = "${var.project_name}-gatekeeper-lambda-policy"
  role = aws_iam_role.gatekeeper_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadPromptSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.agent_prompts.arn
      },
      {
        Sid    = "DecryptWithKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.secrets.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.central_account_id}:*"
      }
    ]
  })
}

# =============================================================================
# API Gateway (HTTP API - simpler and cheaper than REST API)
# =============================================================================

resource "aws_apigatewayv2_api" "gatekeeper" {
  name          = "${var.project_name}-gatekeeper"
  protocol_type = "HTTP"
  description   = "API Gateway for prompt gatekeeper"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = local.default_tags
}

resource "aws_apigatewayv2_stage" "gatekeeper" {
  api_id      = aws_apigatewayv2_api.gatekeeper.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.gatekeeper_api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.default_tags
}

resource "aws_apigatewayv2_integration" "gatekeeper" {
  api_id             = aws_apigatewayv2_api.gatekeeper.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.gatekeeper.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "gatekeeper" {
  api_id    = aws_apigatewayv2_api.gatekeeper.id
  route_key = "POST /get-prompts"
  target    = "integrations/${aws_apigatewayv2_integration.gatekeeper.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "gatekeeper_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gatekeeper.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.gatekeeper.execution_arn}/*/*"
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "gatekeeper_api" {
  name              = "/aws/apigateway/${var.project_name}-gatekeeper"
  retention_in_days = 30

  tags = local.default_tags
}

# CloudWatch Log Group for Lambda (created explicitly so metric filter works)
resource "aws_cloudwatch_log_group" "gatekeeper_lambda" {
  name              = "/aws/lambda/${var.project_name}-gatekeeper"
  retention_in_days = 30

  tags = local.default_tags
}

# =============================================================================
# Monitoring: Alert on failed authentication attempts
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_auth_failures" {
  name           = "${var.project_name}-gatekeeper-auth-failures"
  pattern        = "\"Invalid signature\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperAuthFailures"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_auth_failures" {
  alarm_name          = "${var.project_name}-gatekeeper-auth-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperAuthFailures"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Multiple failed authentication attempts to gatekeeper"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

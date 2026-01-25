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
      ALLOWED_CLIENT_ACCOUNTS = join(",", var.client_account_ids)
      ALERT_SNS_TOPIC         = aws_sns_topic.security_alerts.arn
      MAX_REQUESTS_PER_MINUTE = tostring(var.gatekeeper_rate_limit)
      ALLOWED_IP_CIDRS        = length(var.gatekeeper_allowed_ips) > 0 ? join(",", var.gatekeeper_allowed_ips) : ""
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
      },
      {
        Sid    = "PublishSecurityAlerts"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
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

  # API Gateway level throttling
  default_route_settings {
    throttling_rate_limit  = var.gatekeeper_throttle_rate
    throttling_burst_limit = var.gatekeeper_throttle_burst
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.gatekeeper_api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
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

# =============================================================================
# Monitoring: Rate Limiting Events
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_rate_limited" {
  name           = "${var.project_name}-gatekeeper-rate-limited"
  pattern        = "\"RATE_LIMITED\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperRateLimited"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_rate_limited" {
  alarm_name          = "${var.project_name}-gatekeeper-rate-limited"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperRateLimited"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Multiple rate limit hits - possible abuse"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

# =============================================================================
# Monitoring: Replay Attack Attempts
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_replay_attack" {
  name           = "${var.project_name}-gatekeeper-replay-attack"
  pattern        = "\"REPLAY_ATTEMPT\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperReplayAttempt"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_replay_attack" {
  alarm_name          = "${var.project_name}-gatekeeper-replay-attack"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperReplayAttempt"
  namespace           = "${var.project_name}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "CRITICAL: Replay attack attempt detected!"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

# =============================================================================
# Monitoring: Unauthorized Account Access
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_unauthorized" {
  name           = "${var.project_name}-gatekeeper-unauthorized"
  pattern        = "\"unauthorized_account\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperUnauthorizedAccount"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_unauthorized" {
  alarm_name          = "${var.project_name}-gatekeeper-unauthorized"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperUnauthorizedAccount"
  namespace           = "${var.project_name}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "CRITICAL: Access attempt from unauthorized account!"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

# =============================================================================
# Monitoring: Multiple Failed Attempts (aggregate)
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_multiple_failures" {
  name           = "${var.project_name}-gatekeeper-multiple-failures"
  pattern        = "\"MULTIPLE_FAILED_ATTEMPTS\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperMultipleFailures"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_multiple_failures" {
  alarm_name          = "${var.project_name}-gatekeeper-multiple-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperMultipleFailures"
  namespace           = "${var.project_name}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "CRITICAL: Account has multiple failed attempts - possible attack!"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

# =============================================================================
# Monitoring: IP Blocked Events
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_ip_blocked" {
  name           = "${var.project_name}-gatekeeper-ip-blocked"
  pattern        = "\"IP_BLOCKED\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperIPBlocked"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_ip_blocked" {
  alarm_name          = "${var.project_name}-gatekeeper-ip-blocked"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperIPBlocked"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Multiple access attempts from unauthorized IPs"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

# =============================================================================
# Monitoring: Request Body Tampering
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "gatekeeper_body_tampered" {
  name           = "${var.project_name}-gatekeeper-body-tampered"
  pattern        = "\"BODY_TAMPERED\""
  log_group_name = aws_cloudwatch_log_group.gatekeeper_lambda.name

  metric_transformation {
    name      = "GatekeeperBodyTampered"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "gatekeeper_body_tampered" {
  alarm_name          = "${var.project_name}-gatekeeper-body-tampered"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GatekeeperBodyTampered"
  namespace           = "${var.project_name}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "CRITICAL: Request body tampering detected - possible MITM attack!"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = local.default_tags
}

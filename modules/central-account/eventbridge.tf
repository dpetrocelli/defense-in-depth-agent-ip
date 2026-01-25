# =============================================================================
# Central Event Bus for Cross-Account Monitoring
# =============================================================================
# Receives events from all client accounts for centralized monitoring

resource "aws_cloudwatch_event_bus" "central" {
  name = "${var.project_name}-central-events"
  tags = var.tags
}

# Policy to allow client accounts to send events
resource "aws_cloudwatch_event_bus_policy" "allow_clients" {
  event_bus_name = aws_cloudwatch_event_bus.central.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowClientAccountsToPutEvents"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.client_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.central.arn
      }
    ]
  })
}

# =============================================================================
# Rules to Process Incoming Events
# =============================================================================

# Rule: Security Alerts from clients
resource "aws_cloudwatch_event_rule" "security_alerts" {
  name           = "${var.project_name}-security-alerts"
  description    = "Process security alerts from client accounts"
  event_bus_name = aws_cloudwatch_event_bus.central.name

  event_pattern = jsonencode({
    source      = ["bedrock-protected.security"]
    detail-type = ["SecurityAlert"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "security_to_sns" {
  rule           = aws_cloudwatch_event_rule.security_alerts.name
  event_bus_name = aws_cloudwatch_event_bus.central.name
  target_id      = "security-to-sns"
  arn            = aws_sns_topic.security_alerts.arn
}

# Rule: Lambda Errors from clients
resource "aws_cloudwatch_event_rule" "lambda_errors" {
  name           = "${var.project_name}-lambda-errors"
  description    = "Process Lambda errors from client accounts"
  event_bus_name = aws_cloudwatch_event_bus.central.name

  event_pattern = jsonencode({
    source      = ["bedrock-protected.lambda"]
    detail-type = ["LambdaError", "LambdaThrottled"]
  })

  tags = var.tags
}

# Rule: API Gateway events from clients
resource "aws_cloudwatch_event_rule" "api_events" {
  name           = "${var.project_name}-api-events"
  description    = "Process API Gateway events from client accounts"
  event_bus_name = aws_cloudwatch_event_bus.central.name

  event_pattern = jsonencode({
    source      = ["bedrock-protected.api"]
    detail-type = ["ApiRequest", "ApiError", "RateLimitExceeded"]
  })

  tags = var.tags
}

# Rule: Prompt Injection Attempts
resource "aws_cloudwatch_event_rule" "injection_attempts" {
  name           = "${var.project_name}-injection-attempts"
  description    = "Process prompt injection attempts from client accounts"
  event_bus_name = aws_cloudwatch_event_bus.central.name

  event_pattern = jsonencode({
    source      = ["bedrock-protected.security"]
    detail-type = ["PromptInjectionAttempt", "PromptLeakageDetected"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "injection_to_sns" {
  rule           = aws_cloudwatch_event_rule.injection_attempts.name
  event_bus_name = aws_cloudwatch_event_bus.central.name
  target_id      = "injection-to-sns"
  arn            = aws_sns_topic.security_alerts.arn

  input_transformer {
    input_paths = {
      account    = "$.account"
      time       = "$.time"
      alert_type = "$.detail.alert_type"
      risk_score = "$.detail.risk_score"
      indicators = "$.detail.indicators"
    }
    input_template = <<EOF
{
  "alert_type": <alert_type>,
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "risk_score": <risk_score>,
  "indicators": <indicators>,
  "message": "Prompt injection/leakage attempt detected"
}
EOF
  }
}

# =============================================================================
# CloudWatch Log Group for Event Archive
# =============================================================================

resource "aws_cloudwatch_log_group" "event_archive" {
  name              = "/aws/events/${var.project_name}-central"
  retention_in_days = 90
  tags              = var.tags
}

# Archive all events to CloudWatch Logs for analysis
resource "aws_cloudwatch_event_rule" "archive_all" {
  name           = "${var.project_name}-archive-all-events"
  description    = "Archive all events to CloudWatch Logs"
  event_bus_name = aws_cloudwatch_event_bus.central.name

  event_pattern = jsonencode({
    source = [{
      prefix = "bedrock-protected"
    }]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "archive_to_logs" {
  rule           = aws_cloudwatch_event_rule.archive_all.name
  event_bus_name = aws_cloudwatch_event_bus.central.name
  target_id      = "archive-to-logs"
  arn            = aws_cloudwatch_log_group.event_archive.arn
}

# IAM role for EventBridge to write to CloudWatch Logs
resource "aws_iam_role" "eventbridge_logs" {
  name = "${var.project_name}-eventbridge-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_logs" {
  name = "write-to-logs"
  role = aws_iam_role.eventbridge_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.event_archive.arn}:*"
      }
    ]
  })
}

# CloudWatch Logs resource policy to allow EventBridge
resource "aws_cloudwatch_log_resource_policy" "eventbridge" {
  policy_name = "${var.project_name}-eventbridge-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.event_archive.arn}:*"
      }
    ]
  })
}

# =============================================================================
# CloudWatch Metric Filters for Alerting
# =============================================================================

# Metric filter for security alerts count
resource "aws_cloudwatch_log_metric_filter" "security_alerts" {
  name           = "${var.project_name}-security-alerts-count"
  pattern        = "{ $.detail-type = \"SecurityAlert\" }"
  log_group_name = aws_cloudwatch_log_group.event_archive.name

  metric_transformation {
    name          = "SecurityAlerts"
    namespace     = "${var.project_name}/CentralMonitoring"
    value         = "1"
    default_value = "0"
    dimensions = {
      AccountId = "$.account"
    }
  }
}

# Metric filter for injection attempts
resource "aws_cloudwatch_log_metric_filter" "injection_attempts" {
  name           = "${var.project_name}-injection-attempts-count"
  pattern        = "{ $.detail-type = \"PromptInjectionAttempt\" }"
  log_group_name = aws_cloudwatch_log_group.event_archive.name

  metric_transformation {
    name          = "InjectionAttempts"
    namespace     = "${var.project_name}/CentralMonitoring"
    value         = "1"
    default_value = "0"
    dimensions = {
      AccountId = "$.account"
    }
  }
}

# Metric filter for API requests
resource "aws_cloudwatch_log_metric_filter" "api_requests" {
  name           = "${var.project_name}-api-requests-count"
  pattern        = "{ $.detail-type = \"ApiRequest\" }"
  log_group_name = aws_cloudwatch_log_group.event_archive.name

  metric_transformation {
    name          = "ApiRequests"
    namespace     = "${var.project_name}/CentralMonitoring"
    value         = "1"
    default_value = "0"
    dimensions = {
      AccountId = "$.account"
    }
  }
}

# Metric filter for Lambda errors
resource "aws_cloudwatch_log_metric_filter" "lambda_errors" {
  name           = "${var.project_name}-lambda-errors-count"
  pattern        = "{ $.detail-type = \"LambdaError\" }"
  log_group_name = aws_cloudwatch_log_group.event_archive.name

  metric_transformation {
    name          = "LambdaErrors"
    namespace     = "${var.project_name}/CentralMonitoring"
    value         = "1"
    default_value = "0"
    dimensions = {
      AccountId = "$.account"
    }
  }
}

# =============================================================================
# AWS Budgets for Cost Alerting
# =============================================================================
# Monitor costs for the Bedrock Protected Mode infrastructure

# Budget for overall project costs
resource "aws_budgets_budget" "project_monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$${var.project_name}"
    ]
  }

  # Alert at 50% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  # Alert at 80% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  # Alert at 100% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  # Forecasted to exceed budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  tags = var.tags
}

# Specific budget for Bedrock usage (can get expensive quickly)
resource "aws_budgets_budget" "bedrock_usage" {
  name         = "${var.project_name}-bedrock-budget"
  budget_type  = "COST"
  limit_amount = var.bedrock_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Bedrock"
    ]
  }

  # Alert at 50% of Bedrock budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  # Alert at 80% of Bedrock budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  # Alert at 100% - CRITICAL for Bedrock
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  tags = var.tags
}

# Budget for Lambda compute (indicator of usage volume)
resource "aws_budgets_budget" "lambda_usage" {
  name         = "${var.project_name}-lambda-budget"
  budget_type  = "COST"
  limit_amount = var.lambda_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "AWS Lambda"
    ]
  }

  # Alert at 80% of Lambda budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.security_alerts.arn]
  }

  tags = var.tags
}

# =============================================================================
# Cost Anomaly Detection
# =============================================================================

resource "aws_ce_anomaly_monitor" "project" {
  name              = "${var.project_name}-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = var.tags
}

resource "aws_ce_anomaly_subscription" "alerts" {
  name      = "${var.project_name}-anomaly-alerts"
  frequency = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.project.arn
  ]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.security_alerts.arn
  }

  # Alert if anomaly impact is > $10 or > 20% above expected
  threshold_expression {
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["10"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        values        = ["20"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = var.tags
}

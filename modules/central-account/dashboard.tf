# =============================================================================
# Central CloudWatch Dashboard
# =============================================================================
# Provides visibility into all client accounts from the central account

resource "aws_cloudwatch_dashboard" "central" {
  dashboard_name = "${var.project_name}-central-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Overview metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "API Requests (All Clients)"
          region = data.aws_region.current.id
          metrics = [
            [{ expression = "SEARCH('{${var.project_name}/CentralMonitoring,AccountId} MetricName=\"ApiRequests\"', 'Sum', 300)", id = "e1", label = "Requests" }]
          ]
          view    = "timeSeries"
          stacked = true
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Lambda Errors (All Clients)"
          region = data.aws_region.current.id
          metrics = [
            [{ expression = "SEARCH('{${var.project_name}/CentralMonitoring,AccountId} MetricName=\"LambdaErrors\"', 'Sum', 300)", id = "e1", label = "Errors" }]
          ]
          view    = "timeSeries"
          stacked = true
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Security Alerts (All Clients)"
          region = data.aws_region.current.id
          metrics = [
            [{ expression = "SEARCH('{${var.project_name}/CentralMonitoring,AccountId} MetricName=\"SecurityAlerts\"', 'Sum', 300)", id = "e1", label = "Alerts" }]
          ]
          view    = "timeSeries"
          stacked = true
          period  = 300
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          title  = "Injection Attempts (All Clients)"
          region = data.aws_region.current.id
          metrics = [
            [{ expression = "SEARCH('{${var.project_name}/CentralMonitoring,AccountId} MetricName=\"InjectionAttempts\"', 'Sum', 300)", id = "e1", label = "Attempts" }]
          ]
          view    = "timeSeries"
          stacked = true
          period  = 300
          stat    = "Sum"
        }
      },

      # Row 2: Gatekeeper Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Gatekeeper - Requests"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-gatekeeper", { stat = "Sum", label = "Total Requests" }],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-gatekeeper", { stat = "Sum", label = "Errors", color = "#d62728" }]
          ]
          view   = "timeSeries"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Gatekeeper - Latency"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-gatekeeper", { stat = "Average", label = "Avg Duration" }],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-gatekeeper", { stat = "p99", label = "p99 Duration" }]
          ]
          view   = "timeSeries"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Gatekeeper - Security Events"
          region = data.aws_region.current.id
          metrics = [
            ["${var.project_name}/Gatekeeper", "RateLimitExceeded", { stat = "Sum", label = "Rate Limited" }],
            ["${var.project_name}/Gatekeeper", "ReplayAttackBlocked", { stat = "Sum", label = "Replay Blocked" }],
            ["${var.project_name}/Gatekeeper", "IPBlocked", { stat = "Sum", label = "IP Blocked" }],
            ["${var.project_name}/Gatekeeper", "BodyTampered", { stat = "Sum", label = "Body Tampered" }]
          ]
          view   = "timeSeries"
          period = 300
        }
      },

      # Row 3: Security Summary
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Security Events by Type"
          region = data.aws_region.current.id
          metrics = [
            ["${var.project_name}/CentralMonitoring", "SecurityAlerts", { stat = "Sum" }],
            ["${var.project_name}/CentralMonitoring", "InjectionAttempts", { stat = "Sum" }],
            ["${var.project_name}/CentralMonitoring", "LambdaErrors", { stat = "Sum" }]
          ]
          view   = "bar"
          period = 86400
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Recent Security Events"
          region = data.aws_region.current.id
          query  = "SOURCE '/aws/events/${var.project_name}-central' | fields @timestamp, detail.alert_type as AlertType, account as Account, detail.message as Message | filter detail-type like /Security|Injection|Leakage/ | sort @timestamp desc | limit 20"
          view   = "table"
        }
      },

      # Row 4: Client Account Breakdown
      {
        type   = "text"
        x      = 0
        y      = 18
        width  = 24
        height = 1
        properties = {
          markdown = "## Client Account Activity"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 19
        width  = 12
        height = 6
        properties = {
          title  = "Requests by Client Account"
          region = data.aws_region.current.id
          metrics = [
            [{ expression = "SEARCH('{${var.project_name}/CentralMonitoring,AccountId} MetricName=\"ApiRequests\"', 'Sum', 3600)", id = "e1" }]
          ]
          view   = "pie"
          period = 3600
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 19
        width  = 12
        height = 6
        properties = {
          title  = "Errors by Client Account"
          region = data.aws_region.current.id
          metrics = [
            [{ expression = "SEARCH('{${var.project_name}/CentralMonitoring,AccountId} MetricName=\"LambdaErrors\"', 'Sum', 3600)", id = "e1" }]
          ]
          view   = "pie"
          period = 3600
        }
      },

      # Row 5: Audit Trail
      {
        type   = "log"
        x      = 0
        y      = 25
        width  = 24
        height = 6
        properties = {
          title  = "All Events (Last 100)"
          region = data.aws_region.current.id
          query  = "SOURCE '/aws/events/${var.project_name}-central' | fields @timestamp, `detail-type` as EventType, account as Account, detail.message as Message | sort @timestamp desc | limit 100"
          view   = "table"
        }
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarms for Critical Events
# =============================================================================

# Alarm: High rate of injection attempts
resource "aws_cloudwatch_metric_alarm" "high_injection_rate" {
  alarm_name          = "${var.project_name}-high-injection-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InjectionAttempts"
  namespace           = "${var.project_name}/CentralMonitoring"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "High rate of prompt injection attempts detected"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]

  tags = var.tags
}

# Alarm: High error rate
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "LambdaErrors"
  namespace           = "${var.project_name}/CentralMonitoring"
  period              = 300
  statistic           = "Sum"
  threshold           = 20
  alarm_description   = "High error rate across client accounts"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]

  tags = var.tags
}

# Alarm: Gatekeeper errors
resource "aws_cloudwatch_metric_alarm" "gatekeeper_errors" {
  alarm_name          = "${var.project_name}-gatekeeper-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Gatekeeper Lambda experiencing errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${var.project_name}-gatekeeper"
  }

  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]

  tags = var.tags
}

# Note: gatekeeper_rate_limited alarm is defined in gatekeeper.tf
# Note: data.aws_region.current is defined in main.tf

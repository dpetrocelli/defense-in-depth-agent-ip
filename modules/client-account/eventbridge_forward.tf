# =============================================================================
# EventBridge Forwarding to Central Account
# =============================================================================
# Forwards events to the central Event Bus for aggregated monitoring

# Only create resources if central_event_bus_arn is provided
locals {
  enable_event_forwarding = var.central_event_bus_arn != ""
}

# =============================================================================
# IAM Role for Cross-Account EventBridge
# =============================================================================

resource "aws_iam_role" "eventbridge_forward" {
  count = local.enable_event_forwarding ? 1 : 0

  name = "${var.project_name}-eventbridge-forward"

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

  tags = local.default_tags
}

resource "aws_iam_role_policy" "eventbridge_forward" {
  count = local.enable_event_forwarding ? 1 : 0

  name = "forward-to-central"
  role = aws_iam_role.eventbridge_forward[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = var.central_event_bus_arn
      }
    ]
  })
}

# =============================================================================
# Forward Lambda Metrics/Events
# =============================================================================

# Rule: Lambda Invocations (sampled for cost efficiency)
resource "aws_cloudwatch_event_rule" "forward_lambda_errors" {
  count = local.enable_event_forwarding ? 1 : 0

  name        = "${var.project_name}-forward-lambda-errors"
  description = "Forward Lambda errors to central Event Bus"

  event_pattern = jsonencode({
    source      = ["aws.lambda"]
    detail-type = ["Lambda Function Invocation Result - Failure"]
    detail = {
      requestContext = {
        functionArn = [{
          prefix = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}"
        }]
      }
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "lambda_errors_to_central" {
  count = local.enable_event_forwarding ? 1 : 0

  rule      = aws_cloudwatch_event_rule.forward_lambda_errors[0].name
  target_id = "forward-to-central"
  arn       = var.central_event_bus_arn
  role_arn  = aws_iam_role.eventbridge_forward[0].arn

  input_transformer {
    input_paths = {
      account     = "$.account"
      time        = "$.time"
      functionArn = "$.detail.requestContext.functionArn"
      errorType   = "$.detail.responsePayload.errorType"
      errorMsg    = "$.detail.responsePayload.errorMessage"
    }
    input_template = <<EOF
{
  "source": "bedrock-protected.lambda",
  "detail-type": "LambdaError",
  "detail": {
    "account": <account>,
    "timestamp": <time>,
    "function_arn": <functionArn>,
    "error_type": <errorType>,
    "error_message": <errorMsg>,
    "alert_type": "LAMBDA_ERROR"
  }
}
EOF
  }
}

# =============================================================================
# Forward API Gateway Metrics
# =============================================================================

# CloudWatch Logs Subscription for API Gateway access logs
resource "aws_cloudwatch_log_subscription_filter" "api_to_lambda" {
  count = local.enable_event_forwarding ? 1 : 0

  name            = "${var.project_name}-api-events"
  log_group_name  = aws_cloudwatch_log_group.api_gateway.name
  filter_pattern  = "{ $.status >= 400 }"
  destination_arn = aws_lambda_function.event_forwarder[0].arn

  depends_on = [aws_lambda_permission.allow_cloudwatch[0]]
}

# Lambda function to forward events to central Event Bus
resource "aws_lambda_function" "event_forwarder" {
  count = local.enable_event_forwarding ? 1 : 0

  function_name = "${var.project_name}-event-forwarder"
  role          = aws_iam_role.event_forwarder[0].arn
  runtime       = "python3.12"
  handler       = "index.handler"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.event_forwarder[0].output_path
  source_code_hash = data.archive_file.event_forwarder[0].output_base64sha256

  environment {
    variables = {
      CENTRAL_EVENT_BUS_ARN = var.central_event_bus_arn
      PROJECT_NAME          = var.project_name
    }
  }

  tags = local.default_tags
}

data "archive_file" "event_forwarder" {
  count = local.enable_event_forwarding ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda_event_forwarder.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3
import base64
import gzip
from datetime import datetime

eventbridge = boto3.client('events')
CENTRAL_EVENT_BUS_ARN = os.environ['CENTRAL_EVENT_BUS_ARN']
PROJECT_NAME = os.environ['PROJECT_NAME']

def handler(event, context):
    """Forward CloudWatch Logs events to central EventBridge."""

    # Decode CloudWatch Logs data
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_data = json.loads(uncompressed_payload)

    entries = []

    for log_event in log_data.get('logEvents', []):
        try:
            log_message = json.loads(log_event['message'])

            # Determine event type based on status code
            status = log_message.get('status', 0)
            if status >= 500:
                detail_type = 'ApiError'
                severity = 'HIGH'
            elif status == 429:
                detail_type = 'RateLimitExceeded'
                severity = 'MEDIUM'
            elif status >= 400:
                detail_type = 'ApiClientError'
                severity = 'LOW'
            else:
                continue

            entry = {
                'Source': 'bedrock-protected.api',
                'DetailType': detail_type,
                'Detail': json.dumps({
                    'account': context.invoked_function_arn.split(':')[4],
                    'timestamp': datetime.utcnow().isoformat(),
                    'request_id': log_message.get('requestId', ''),
                    'status': status,
                    'route_key': log_message.get('routeKey', ''),
                    'method': log_message.get('httpMethod', ''),
                    'source_ip': log_message.get('ip', ''),
                    'integration_error': log_message.get('integrationError', ''),
                    'severity': severity,
                    'alert_type': detail_type.upper()
                }),
                'EventBusName': CENTRAL_EVENT_BUS_ARN
            }
            entries.append(entry)

        except json.JSONDecodeError:
            continue

    if entries:
        # Send in batches of 10 (EventBridge limit)
        for i in range(0, len(entries), 10):
            batch = entries[i:i+10]
            response = eventbridge.put_events(Entries=batch)

            if response.get('FailedEntryCount', 0) > 0:
                print(f"Failed to send {response['FailedEntryCount']} events")

    return {'statusCode': 200, 'body': f'Forwarded {len(entries)} events'}
PYTHON
    filename = "index.py"
  }
}

resource "aws_iam_role" "event_forwarder" {
  count = local.enable_event_forwarding ? 1 : 0

  name = "${var.project_name}-event-forwarder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "event_forwarder" {
  count = local.enable_event_forwarding ? 1 : 0

  name = "event-forwarder-policy"
  role = aws_iam_role.event_forwarder[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = var.central_event_bus_arn
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count = local.enable_event_forwarding ? 1 : 0

  statement_id  = "AllowCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_forwarder[0].function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.api_gateway.arn}:*"
}

# =============================================================================
# Forward Security Events (from agent response filter)
# =============================================================================

# Custom metric alarm that triggers security event forwarding
resource "aws_cloudwatch_metric_alarm" "injection_detected" {
  count = local.enable_event_forwarding ? 1 : 0

  alarm_name          = "${var.project_name}-injection-detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InjectionAttempts"
  namespace           = "${var.project_name}/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Prompt injection attempt detected"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_events[0].arn]

  tags = local.default_tags
}

resource "aws_sns_topic" "security_events" {
  count = local.enable_event_forwarding ? 1 : 0

  name = "${var.project_name}-security-events"
  tags = local.default_tags
}

# Lambda to forward security events
resource "aws_sns_topic_subscription" "security_to_lambda" {
  count = local.enable_event_forwarding ? 1 : 0

  topic_arn = aws_sns_topic.security_events[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.security_forwarder[0].arn
}

resource "aws_lambda_function" "security_forwarder" {
  count = local.enable_event_forwarding ? 1 : 0

  function_name = "${var.project_name}-security-forwarder"
  role          = aws_iam_role.event_forwarder[0].arn
  runtime       = "python3.12"
  handler       = "index.handler"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.security_forwarder[0].output_path
  source_code_hash = data.archive_file.security_forwarder[0].output_base64sha256

  environment {
    variables = {
      CENTRAL_EVENT_BUS_ARN = var.central_event_bus_arn
      PROJECT_NAME          = var.project_name
    }
  }

  tags = local.default_tags
}

data "archive_file" "security_forwarder" {
  count = local.enable_event_forwarding ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda_security_forwarder.zip"

  source {
    content  = <<-PYTHON
import json
import os
import boto3
from datetime import datetime

eventbridge = boto3.client('events')
CENTRAL_EVENT_BUS_ARN = os.environ['CENTRAL_EVENT_BUS_ARN']
PROJECT_NAME = os.environ['PROJECT_NAME']

def handler(event, context):
    """Forward security events to central EventBridge."""

    for record in event.get('Records', []):
        sns_message = record.get('Sns', {})
        message = sns_message.get('Message', '{}')

        try:
            alarm_data = json.loads(message)
        except json.JSONDecodeError:
            alarm_data = {'message': message}

        # Determine event type based on alarm name
        alarm_name = alarm_data.get('AlarmName', '')

        if 'injection' in alarm_name.lower():
            detail_type = 'PromptInjectionAttempt'
        elif 'leakage' in alarm_name.lower():
            detail_type = 'PromptLeakageDetected'
        else:
            detail_type = 'SecurityAlert'

        entry = {
            'Source': 'bedrock-protected.security',
            'DetailType': detail_type,
            'Detail': json.dumps({
                'account': context.invoked_function_arn.split(':')[4],
                'timestamp': datetime.utcnow().isoformat(),
                'alarm_name': alarm_name,
                'alarm_state': alarm_data.get('NewStateValue', 'UNKNOWN'),
                'alarm_reason': alarm_data.get('NewStateReason', ''),
                'alert_type': detail_type,
                'severity': 'CRITICAL',
                'message': f'Security event from {PROJECT_NAME}: {detail_type}'
            }),
            'EventBusName': CENTRAL_EVENT_BUS_ARN
        }

        response = eventbridge.put_events(Entries=[entry])

        if response.get('FailedEntryCount', 0) > 0:
            print(f"Failed to send event: {response}")

    return {'statusCode': 200}
PYTHON
    filename = "index.py"
  }
}

resource "aws_lambda_permission" "allow_sns" {
  count = local.enable_event_forwarding ? 1 : 0

  statement_id  = "AllowSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_forwarder[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.security_events[0].arn
}

# =============================================================================
# Heartbeat - Regular check-in from client
# =============================================================================

resource "aws_cloudwatch_event_rule" "heartbeat" {
  count = local.enable_event_forwarding ? 1 : 0

  name                = "${var.project_name}-heartbeat"
  description         = "Send heartbeat to central account every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "heartbeat_to_central" {
  count = local.enable_event_forwarding ? 1 : 0

  rule      = aws_cloudwatch_event_rule.heartbeat[0].name
  target_id = "heartbeat-to-central"
  arn       = var.central_event_bus_arn
  role_arn  = aws_iam_role.eventbridge_forward[0].arn

  input = jsonencode({
    source        = "bedrock-protected.heartbeat"
    "detail-type" = "ClientHeartbeat"
    detail = {
      account      = data.aws_caller_identity.current.account_id
      project_name = var.project_name
      status       = "healthy"
      timestamp    = "$${aws:CurrentTime}"
    }
  })
}

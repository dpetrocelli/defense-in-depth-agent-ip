# =============================================================================
# CloudTrail for Audit
# =============================================================================
# Captures all access attempts and sends them to bucket in central account

resource "aws_cloudtrail" "security_audit" {
  name                          = "${var.project_name}-security-audit"
  s3_bucket_name                = var.central_audit_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = local.default_tags
}

# =============================================================================
# EventBridge Rules for Security Alerts
# =============================================================================

# Rule: Detect Lambda function modifications
resource "aws_cloudwatch_event_rule" "lambda_modified" {
  name        = "${var.project_name}-lambda-modified"
  description = "Detects modifications to Lambda functions"

  event_pattern = jsonencode({
    source      = ["aws.lambda"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["lambda.amazonaws.com"]
      eventName = [
        "UpdateFunctionCode",
        "UpdateFunctionConfiguration",
        "DeleteFunction",
        "CreateFunction",
        "PublishVersion",
        "UpdateAlias"
      ]
      requestParameters = {
        functionName = [{
          prefix = "${var.project_name}-"
        }]
      }
    }
  })

  tags = local.default_tags
}

# Rule: Detect IAM changes to protected roles
resource "aws_cloudwatch_event_rule" "iam_change_attempt" {
  name        = "${var.project_name}-iam-change-attempt"
  description = "Detects attempts to modify IAM roles/policies for protected resources"

  event_pattern = jsonencode({
    source      = ["aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "DeleteRole",
        "DeleteRolePolicy",
        "PutRolePolicy",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "UpdateAssumeRolePolicy"
      ]
      requestParameters = {
        roleName = [{
          prefix = "${var.project_name}-"
        }]
      }
    }
  })

  tags = local.default_tags
}

# Rule: Detect attempts to access Secrets Manager from client account
resource "aws_cloudwatch_event_rule" "secrets_access_attempt" {
  name        = "${var.project_name}-secrets-access-attempt"
  description = "Detects attempts to access cross-account secrets"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["secretsmanager.amazonaws.com"]
      eventName   = ["GetSecretValue", "DescribeSecret"]
      # Alert on any attempt that is not from the Lambda role
      userIdentity = {
        arn = [{
          "anything-but" = {
            suffix = "${var.project_name}-lambda-execution"
          }
        }]
      }
    }
  })

  tags = local.default_tags
}

# =============================================================================
# EventBridge Targets - Send to Central SNS
# =============================================================================

resource "aws_cloudwatch_event_target" "lambda_to_sns" {
  rule      = aws_cloudwatch_event_rule.lambda_modified.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account      = "$.account"
      time         = "$.time"
      user         = "$.detail.userIdentity.arn"
      action       = "$.detail.eventName"
      functionName = "$.detail.requestParameters.functionName"
    }
    input_template = <<EOF
{
  "alert_type": "LAMBDA_MODIFIED",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "function_name": <functionName>,
  "message": "Lambda function was modified - potential tampering detected"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "iam_to_sns" {
  rule      = aws_cloudwatch_event_rule.iam_change_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account  = "$.account"
      time     = "$.time"
      user     = "$.detail.userIdentity.arn"
      action   = "$.detail.eventName"
      roleName = "$.detail.requestParameters.roleName"
    }
    input_template = <<EOF
{
  "alert_type": "IAM_MODIFICATION_ATTEMPT",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "target_role": <roleName>,
  "message": "Attempt to modify protected IAM role"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "secrets_to_sns" {
  rule      = aws_cloudwatch_event_rule.secrets_access_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account   = "$.account"
      time      = "$.time"
      user      = "$.detail.userIdentity.arn"
      action    = "$.detail.eventName"
      errorCode = "$.detail.errorCode"
    }
    input_template = <<EOF
{
  "alert_type": "SECRETS_ACCESS_ATTEMPT",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "result": <errorCode>,
  "message": "Unauthorized attempt to access agent secrets"
}
EOF
  }
}

# =============================================================================
# Rule: Detect CloudTrail tampering (critical - we lose visibility)
# =============================================================================

resource "aws_cloudwatch_event_rule" "cloudtrail_tampering" {
  name        = "${var.project_name}-cloudtrail-tampering"
  description = "Detects attempts to disable or modify CloudTrail logging"

  event_pattern = jsonencode({
    source      = ["aws.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["cloudtrail.amazonaws.com"]
      eventName   = ["StopLogging", "DeleteTrail", "UpdateTrail", "PutEventSelectors"]
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "cloudtrail_to_sns" {
  rule      = aws_cloudwatch_event_rule.cloudtrail_tampering.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account   = "$.account"
      time      = "$.time"
      user      = "$.detail.userIdentity.arn"
      action    = "$.detail.eventName"
      trailName = "$.detail.requestParameters.name"
    }
    input_template = <<EOF
{
  "alert_type": "CLOUDTRAIL_TAMPERING",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "trail": <trailName>,
  "message": "CRITICAL: CloudTrail logging may have been disabled - audit visibility compromised"
}
EOF
  }
}

# =============================================================================
# Rule: Detect Bedrock Model Invocation Logging (CRITICAL - exposes prompts)
# =============================================================================
# If enabled, ALL prompts sent to Bedrock are logged to CloudWatch/S3
# This completely bypasses our prompt protection!

resource "aws_cloudwatch_event_rule" "bedrock_logging_enabled" {
  name        = "${var.project_name}-bedrock-logging-alert"
  description = "CRITICAL: Detects when Bedrock model invocation logging is enabled"

  event_pattern = jsonencode({
    source      = ["aws.bedrock"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["bedrock.amazonaws.com"]
      eventName   = ["PutModelInvocationLoggingConfiguration"]
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "bedrock_logging_to_sns" {
  rule      = aws_cloudwatch_event_rule.bedrock_logging_enabled.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account = "$.account"
      time    = "$.time"
      user    = "$.detail.userIdentity.arn"
    }
    input_template = <<EOF
{
  "alert_type": "BEDROCK_LOGGING_ENABLED",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "message": "CRITICAL: Bedrock model invocation logging was enabled - ALL PROMPTS ARE NOW VISIBLE in CloudWatch/S3. Prompt protection is BYPASSED!"
}
EOF
  }
}

# =============================================================================
# Rule: Detect unauthorized AssumeRole on Lambda role
# =============================================================================

resource "aws_cloudwatch_event_rule" "lambda_role_assumed" {
  name        = "${var.project_name}-lambda-role-assumed"
  description = "Detects when the protected Lambda role is assumed"

  event_pattern = jsonencode({
    source      = ["aws.sts"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["sts.amazonaws.com"]
      eventName   = ["AssumeRole"]
      requestParameters = {
        roleArn = [{
          suffix = "${var.project_name}-lambda-execution"
        }]
      }
      # Alert only if NOT from Lambda service
      userIdentity = {
        invokedBy = [{
          "anything-but" = "lambda.amazonaws.com"
        }]
      }
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "lambda_role_to_sns" {
  rule      = aws_cloudwatch_event_rule.lambda_role_assumed.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account  = "$.account"
      time     = "$.time"
      user     = "$.detail.userIdentity.arn"
      sourceIp = "$.detail.sourceIPAddress"
      roleArn  = "$.detail.requestParameters.roleArn"
    }
    input_template = <<EOF
{
  "alert_type": "UNAUTHORIZED_ROLE_ASSUMPTION",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "source_ip": <sourceIp>,
  "role": <roleArn>,
  "message": "CRITICAL: Protected Lambda role assumed from non-Lambda source"
}
EOF
  }
}

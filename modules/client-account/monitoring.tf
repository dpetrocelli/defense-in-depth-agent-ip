# =============================================================================
# CloudTrail for Audit
# =============================================================================
# Captura todos los intentos de acceso y los envia al bucket en cuenta central

resource "aws_cloudtrail" "security_audit" {
  name                          = "${var.project_name}-security-audit"
  s3_bucket_name                = var.central_audit_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::SSM::Parameter"
      values = ["arn:aws:ssm:${local.region}:${local.client_account_id}:parameter/${var.project_name}/*"]
    }
  }

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::KMS::Key"
      values = [aws_kms_key.prompt_encryption.arn]
    }
  }

  tags = local.default_tags
}

# =============================================================================
# EventBridge Rules for Security Alerts
# =============================================================================

# Rule: Detect attempts to read SSM parameters
resource "aws_cloudwatch_event_rule" "ssm_access_attempt" {
  name        = "${var.project_name}-ssm-access-attempt"
  description = "Detects attempts to read protected SSM parameters"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ssm.amazonaws.com"]
      eventName   = ["GetParameter", "GetParameters", "GetParameterHistory", "GetParametersByPath"]
      requestParameters = {
        name = [{
          prefix = "/${var.project_name}/"
        }]
      }
      # Exclude the deployer role and bedrock service
      userIdentity = {
        arn = [{
          "anything-but" = {
            prefix = "arn:aws:iam::${local.client_account_id}:role/${var.project_name}-"
          }
        }]
      }
    }
  })

  tags = local.default_tags
}

# Rule: Detect attempts to access KMS key
resource "aws_cloudwatch_event_rule" "kms_access_attempt" {
  name        = "${var.project_name}-kms-access-attempt"
  description = "Detects attempts to access the protected KMS key"

  event_pattern = jsonencode({
    source      = ["aws.kms"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["kms.amazonaws.com"]
      eventName   = ["Decrypt", "GetKeyPolicy", "PutKeyPolicy", "DescribeKey"]
      resources = {
        ARN = [aws_kms_key.prompt_encryption.arn]
      }
      userIdentity = {
        arn = [{
          "anything-but" = {
            prefix = "arn:aws:iam::${local.client_account_id}:role/${var.project_name}-"
          }
        }]
      }
    }
  })

  tags = local.default_tags
}

# Rule: Detect attempts to read Bedrock Agent config
resource "aws_cloudwatch_event_rule" "bedrock_access_attempt" {
  name        = "${var.project_name}-bedrock-access-attempt"
  description = "Detects attempts to read Bedrock Agent configuration"

  event_pattern = jsonencode({
    source      = ["aws.bedrock"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["bedrock.amazonaws.com"]
      eventName   = ["GetAgent", "GetAgentVersion", "GetPrompt", "ListPrompts"]
      userIdentity = {
        arn = [{
          "anything-but" = {
            prefix = "arn:aws:iam::${local.client_account_id}:role/${var.project_name}-"
          }
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

# =============================================================================
# EventBridge Targets - Send to Central SNS
# =============================================================================

resource "aws_cloudwatch_event_target" "ssm_to_sns" {
  rule      = aws_cloudwatch_event_rule.ssm_access_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn

  input_transformer {
    input_paths = {
      account   = "$.account"
      time      = "$.time"
      user      = "$.detail.userIdentity.arn"
      action    = "$.detail.eventName"
      resource  = "$.detail.requestParameters.name"
      errorCode = "$.detail.errorCode"
    }
    input_template = <<EOF
{
  "alert_type": "SSM_ACCESS_ATTEMPT",
  "severity": "HIGH",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "resource": <resource>,
  "result": <errorCode>,
  "message": "Unauthorized attempt to access protected SSM parameter"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "kms_to_sns" {
  rule      = aws_cloudwatch_event_rule.kms_access_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn

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
  "alert_type": "KMS_ACCESS_ATTEMPT",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "result": <errorCode>,
  "message": "Unauthorized attempt to access protected KMS key"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "bedrock_to_sns" {
  rule      = aws_cloudwatch_event_rule.bedrock_access_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn

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
  "alert_type": "BEDROCK_ACCESS_ATTEMPT",
  "severity": "HIGH",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "result": <errorCode>,
  "message": "Unauthorized attempt to access Bedrock Agent configuration"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "iam_to_sns" {
  rule      = aws_cloudwatch_event_rule.iam_change_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn

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

# =============================================================================
# IAM Role for EventBridge to publish to SNS cross-account
# =============================================================================

resource "aws_iam_role" "eventbridge_to_sns" {
  name = "${var.project_name}-eventbridge-to-sns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "eventbridge_to_sns" {
  name = "${var.project_name}-eventbridge-to-sns-policy"
  role = aws_iam_role.eventbridge_to_sns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.central_sns_topic_arn
      }
    ]
  })
}

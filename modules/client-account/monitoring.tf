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

# Rule: Detect ECS task definition changes
resource "aws_cloudwatch_event_rule" "ecs_task_modified" {
  name        = "${var.project_name}-ecs-task-modified"
  description = "Detects modifications to ECS task definitions"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ecs.amazonaws.com"]
      eventName   = ["RegisterTaskDefinition", "DeregisterTaskDefinition"]
      requestParameters = {
        family = [{
          prefix = "${var.project_name}-"
        }]
      }
    }
  })

  tags = local.default_tags
}

# Rule: Detect ECS service modifications
resource "aws_cloudwatch_event_rule" "ecs_service_modified" {
  name        = "${var.project_name}-ecs-service-modified"
  description = "Detects modifications to ECS services"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ecs.amazonaws.com"]
      eventName   = ["UpdateService", "DeleteService", "CreateService"]
      requestParameters = {
        cluster = [{
          suffix = "${var.project_name}-agent"
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
      # Alert on any attempt that is not from the ECS task role
      userIdentity = {
        arn = [{
          "anything-but" = {
            suffix = "${var.project_name}-ecs-task"
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

resource "aws_cloudwatch_event_target" "ecs_task_to_sns" {
  rule      = aws_cloudwatch_event_rule.ecs_task_modified.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account  = "$.account"
      time     = "$.time"
      user     = "$.detail.userIdentity.arn"
      action   = "$.detail.eventName"
      family   = "$.detail.requestParameters.family"
    }
    input_template = <<EOF
{
  "alert_type": "ECS_TASK_MODIFIED",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "task_family": <family>,
  "message": "ECS task definition was modified - potential tampering detected"
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "ecs_service_to_sns" {
  rule      = aws_cloudwatch_event_rule.ecs_service_modified.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account = "$.account"
      time    = "$.time"
      user    = "$.detail.userIdentity.arn"
      action  = "$.detail.eventName"
      cluster = "$.detail.requestParameters.cluster"
    }
    input_template = <<EOF
{
  "alert_type": "ECS_SERVICE_MODIFIED",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "cluster": <cluster>,
  "message": "ECS service was modified - potential tampering detected"
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
# Rule: Detect ECS Exec attempts (shell access to container)
# =============================================================================

resource "aws_cloudwatch_event_rule" "ecs_exec_attempt" {
  name        = "${var.project_name}-ecs-exec-attempt"
  description = "Detects attempts to execute commands in ECS containers"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ecs.amazonaws.com"]
      eventName   = ["ExecuteCommand"]
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "ecs_exec_to_sns" {
  rule      = aws_cloudwatch_event_rule.ecs_exec_attempt.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account   = "$.account"
      time      = "$.time"
      user      = "$.detail.userIdentity.arn"
      cluster   = "$.detail.requestParameters.cluster"
      task      = "$.detail.requestParameters.task"
      errorCode = "$.detail.errorCode"
    }
    input_template = <<EOF
{
  "alert_type": "ECS_EXEC_ATTEMPT",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "cluster": <cluster>,
  "task": <task>,
  "result": <errorCode>,
  "message": "ALERT: Attempt to execute shell command in protected container"
}
EOF
  }
}

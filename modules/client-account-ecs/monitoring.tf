# =============================================================================
# CloudTrail and Security Monitoring for ECS
# =============================================================================
# Alerts on:
# - ECS Exec attempts (CRITICAL - shell access)
# - Task definition changes (sidecar injection)
# - Service modifications
# - IAM role changes
# - Bedrock logging enabled (CRITICAL - exposes prompts)
# - CloudTrail tampering
# - Secrets Manager access attempts
# =============================================================================

# CloudTrail
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
# Rule: ECS Exec Attempts (CRITICAL)
# =============================================================================
# ECS Exec is DISABLED, but if someone tries it, we want to know.

resource "aws_cloudwatch_event_rule" "ecs_exec_attempt" {
  name        = "${var.project_name}-ecs-exec-attempt"
  description = "CRITICAL: Detects attempts to exec into ECS containers"

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
      errorCode = "$.detail.errorCode"
      cluster   = "$.detail.requestParameters.cluster"
      task      = "$.detail.requestParameters.task"
    }
    input_template = <<EOF
{
  "alert_type": "ECS_EXEC_ATTEMPT",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "error_code": <errorCode>,
  "cluster": <cluster>,
  "task": <task>,
  "message": "CRITICAL: Someone attempted to exec into ECS container - this should be blocked"
}
EOF
  }
}

# =============================================================================
# Rule: Task Definition Changes (Sidecar Injection Risk)
# =============================================================================

resource "aws_cloudwatch_event_rule" "task_def_change" {
  name        = "${var.project_name}-task-def-change"
  description = "Detects new task definition registrations (potential sidecar injection)"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ecs.amazonaws.com"]
      eventName   = ["RegisterTaskDefinition", "DeregisterTaskDefinition"]
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "task_def_to_sns" {
  rule      = aws_cloudwatch_event_rule.task_def_change.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account = "$.account"
      time    = "$.time"
      user    = "$.detail.userIdentity.arn"
      action  = "$.detail.eventName"
      family  = "$.detail.requestParameters.family"
    }
    input_template = <<EOF
{
  "alert_type": "TASK_DEFINITION_CHANGE",
  "severity": "HIGH",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "task_family": <family>,
  "message": "Task definition was modified - check for sidecar injection or entrypoint changes"
}
EOF
  }
}

# =============================================================================
# Rule: ECS Service Modifications
# =============================================================================

resource "aws_cloudwatch_event_rule" "ecs_service_change" {
  name        = "${var.project_name}-ecs-service-change"
  description = "Detects ECS service modifications"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ecs.amazonaws.com"]
      eventName = [
        "UpdateService",
        "DeleteService",
        "CreateService"
      ]
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "ecs_service_to_sns" {
  rule      = aws_cloudwatch_event_rule.ecs_service_change.name
  target_id = "send-to-central-sns"
  arn       = var.central_sns_topic_arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn

  input_transformer {
    input_paths = {
      account = "$.account"
      time    = "$.time"
      user    = "$.detail.userIdentity.arn"
      action  = "$.detail.eventName"
      service = "$.detail.requestParameters.service"
    }
    input_template = <<EOF
{
  "alert_type": "ECS_SERVICE_MODIFIED",
  "severity": "HIGH",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "service": <service>,
  "message": "ECS service was modified - potential tampering"
}
EOF
  }
}

# =============================================================================
# Rule: IAM Changes to Protected Roles
# =============================================================================

resource "aws_cloudwatch_event_rule" "iam_change" {
  name        = "${var.project_name}-iam-change"
  description = "Detects IAM changes to protected roles"

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
        "UpdateAssumeRolePolicy",
        "DeleteRolePermissionsBoundary"
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

resource "aws_cloudwatch_event_target" "iam_to_sns" {
  rule      = aws_cloudwatch_event_rule.iam_change.name
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
  "alert_type": "IAM_MODIFICATION",
  "severity": "CRITICAL",
  "account": <account>,
  "timestamp": <time>,
  "user": <user>,
  "action": <action>,
  "target_role": <roleName>,
  "message": "CRITICAL: Protected IAM role was modified"
}
EOF
  }
}

# =============================================================================
# Rule: Bedrock Model Invocation Logging (CRITICAL)
# =============================================================================

resource "aws_cloudwatch_event_rule" "bedrock_logging" {
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
  rule      = aws_cloudwatch_event_rule.bedrock_logging.name
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
  "message": "CRITICAL: Bedrock model invocation logging was enabled - ALL PROMPTS ARE NOW VISIBLE. Prompt protection is BYPASSED!"
}
EOF
  }
}

# =============================================================================
# Rule: CloudTrail Tampering
# =============================================================================

resource "aws_cloudwatch_event_rule" "cloudtrail_tampering" {
  name        = "${var.project_name}-cloudtrail-tampering"
  description = "CRITICAL: Detects attempts to disable CloudTrail"

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
# Rule: Secrets Manager Access Attempts (from non-task role)
# =============================================================================

resource "aws_cloudwatch_event_rule" "secrets_access" {
  name        = "${var.project_name}-secrets-access-attempt"
  description = "Detects unauthorized attempts to access secrets"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["secretsmanager.amazonaws.com"]
      eventName   = ["GetSecretValue", "DescribeSecret"]
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

resource "aws_cloudwatch_event_target" "secrets_to_sns" {
  rule      = aws_cloudwatch_event_rule.secrets_access.name
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
  "severity": "HIGH",
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
# Rule: Unauthorized AssumeRole on Task Role
# =============================================================================

resource "aws_cloudwatch_event_rule" "task_role_assumed" {
  name        = "${var.project_name}-task-role-assumed"
  description = "Detects when the ECS task role is assumed from non-ECS source"

  event_pattern = jsonencode({
    source      = ["aws.sts"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["sts.amazonaws.com"]
      eventName   = ["AssumeRole"]
      requestParameters = {
        roleArn = [{
          suffix = "${var.project_name}-ecs-task"
        }]
      }
      userIdentity = {
        invokedBy = [{
          "anything-but" = "ecs-tasks.amazonaws.com"
        }]
      }
    }
  })

  tags = local.default_tags
}

resource "aws_cloudwatch_event_target" "task_role_to_sns" {
  rule      = aws_cloudwatch_event_rule.task_role_assumed.name
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
  "message": "CRITICAL: ECS task role assumed from non-ECS source"
}
EOF
  }
}

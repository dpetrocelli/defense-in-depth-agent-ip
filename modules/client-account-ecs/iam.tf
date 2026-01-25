# =============================================================================
# IAM Roles for ECS
# =============================================================================
# Two roles:
# 1. Execution Role - Used by ECS to pull images and write logs
# 2. Task Role - Used by the container to access AWS services
#
# SECURITY:
# - Permission boundary limits maximum permissions
# - Deny dangerous actions (iam:*, etc.)
# =============================================================================

# =============================================================================
# ECS Execution Role (pulls images, writes logs)
# =============================================================================

resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-policy"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${local.region}:${var.central_account_id}:repository/${var.project_name}-agent"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs.arn}:*"
      }
    ]
  })
}

# =============================================================================
# ECS Task Role (container permissions)
# =============================================================================

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ecs:${local.region}:${local.client_account_id}:*"
          }
          StringEquals = {
            "aws:SourceAccount" = local.client_account_id
          }
        }
      }
    ]
  })

  # SECURITY: Permission boundary
  permissions_boundary = aws_iam_policy.task_permission_boundary.arn

  tags = local.default_tags
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeBedrock"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.foundation_model}"
      },
      {
        Sid    = "PreflightCheckBedrockLogging"
        Effect = "Allow"
        Action = [
          "bedrock:GetModelInvocationLoggingConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadSecretsFromCentralAccount"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.agent_prompts_secret_arn
      },
      {
        Sid    = "DecryptSecretsWithKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.secrets_kms_key_arn
      },
      {
        Sid    = "GetCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Permission Boundary
# =============================================================================

resource "aws_iam_policy" "task_permission_boundary" {
  name        = "${var.project_name}-task-boundary"
  description = "Permission boundary for ECS task role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrock"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetModelInvocationLoggingConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${var.central_account_id}:secret:${var.project_name}/*"
      },
      {
        Sid    = "AllowKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${local.region}:${var.central_account_id}:key/*"
      },
      {
        Sid    = "AllowSTS"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDangerousActions"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*",
          "sts:AssumeRole"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.default_tags
}

# =============================================================================
# EventBridge Role for Cross-Account SNS
# =============================================================================

resource "aws_iam_role" "eventbridge_to_sns" {
  name = "${var.project_name}-eventbridge-sns"

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
  name = "${var.project_name}-eventbridge-sns-policy"
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

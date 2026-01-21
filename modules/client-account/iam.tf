# =============================================================================
# ECS Execution Role
# =============================================================================
# Used by ECS to pull images and write logs

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

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow pulling from cross-account ECR
resource "aws_iam_role_policy" "ecs_execution_ecr" {
  name = "${var.project_name}-ecs-execution-ecr"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountECR"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${local.region}:${var.central_account_id}:repository/${var.project_name}-agent"
      },
      {
        Sid    = "AllowECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# ECS Task Role Permission Boundary
# =============================================================================
# Limits what the task role can do even if someone modifies its policies

resource "aws_iam_policy" "task_permission_boundary" {
  name        = "${var.project_name}-task-boundary"
  description = "Permission boundary for ECS task role - limits maximum permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrock"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/*"
      },
      {
        Sid    = "AllowSecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        # Only secrets in the central account with our prefix
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
        Sid    = "DenyEverythingElse"
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
# ECS Task Role
# =============================================================================
# Used by the container to access AWS services

resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task"

  # Security: Permission boundary limits max permissions even if policies are modified
  permissions_boundary = aws_iam_policy.task_permission_boundary.arn

  # Security: Restrict to only tasks running in our protected cluster
  # This prevents the client from creating arbitrary tasks with this role
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
          StringEquals = {
            "aws:SourceAccount" = local.client_account_id
          }
          ArnLike = {
            # Only tasks in our specific cluster can assume this role
            # Format: arn:aws:ecs:region:account:task/cluster-name/task-id
            "aws:SourceArn" = "arn:aws:ecs:${local.region}:${local.client_account_id}:task/${var.project_name}-agent/*"
          }
        }
      }
    ]
  })

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
      }
    ]
  })
}

# =============================================================================
# IAM Role for Deployer (used by central account)
# =============================================================================

resource "aws_iam_role" "deployer" {
  name = "${var.project_name}-deployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.central_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.project_name
          }
        }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "deployer" {
  name = "${var.project_name}-deployer-policy"
  role = aws_iam_role.deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageECS"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ecs:cluster" = "arn:aws:ecs:${local.region}:${local.client_account_id}:cluster/${var.project_name}-agent"
          }
        }
      },
      {
        Sid    = "PassRoleToECS"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
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

# =============================================================================
# Lambda Execution Role
# =============================================================================
# Used by Lambda to pull images, write logs, and access AWS services

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.client_account_id
          }
        }
      }
    ]
  })

  # Security: Permission boundary limits max permissions
  permissions_boundary = aws_iam_policy.lambda_permission_boundary.arn

  tags = local.default_tags
}

# Basic Lambda execution policy (logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda execution policy for cross-account ECR and services
resource "aws_iam_role_policy" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution.id

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
      },
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
# Lambda Permission Boundary
# =============================================================================
# Limits what the Lambda role can do even if someone modifies its policies

resource "aws_iam_policy" "lambda_permission_boundary" {
  name        = "${var.project_name}-lambda-boundary"
  description = "Permission boundary for Lambda role - limits maximum permissions"

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
        Sid    = "AllowLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.client_account_id}:*"
      },
      {
        Sid    = "AllowECR"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
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
        Sid    = "ManageLambda"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = "arn:aws:lambda:${local.region}:${local.client_account_id}:function:${var.project_name}-agent"
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

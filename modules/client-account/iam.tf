# =============================================================================
# IAM Role for Bedrock Agent
# =============================================================================

resource "aws_iam_role" "bedrock_agent" {
  name = "${var.project_name}-bedrock-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
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

  tags = local.default_tags
}

resource "aws_iam_role_policy" "bedrock_agent" {
  name = "${var.project_name}-bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeFoundationModel"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.foundation_model}"
      },
      {
        Sid    = "DecryptPrompts"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.prompt_encryption.arn
      },
      {
        Sid    = "ReadSSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.system_prompt.arn,
          aws_ssm_parameter.instruction_prompt.arn
        ]
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
        Sid    = "ManageBedrockAgent"
        Effect = "Allow"
        Action = [
          "bedrock:CreateAgent",
          "bedrock:UpdateAgent",
          "bedrock:DeleteAgent",
          "bedrock:GetAgent",
          "bedrock:PrepareAgent",
          "bedrock:CreateAgentAlias",
          "bedrock:UpdateAgentAlias",
          "bedrock:DeleteAgentAlias",
          "bedrock:GetAgentAlias",
          "bedrock:ListAgentAliases"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageSSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DeleteParameter"
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.client_account_id}:parameter/${var.project_name}/*"
      },
      {
        Sid    = "ManageKMS"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.prompt_encryption.arn
      },
      {
        Sid    = "PassRoleToBedrock"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.bedrock_agent.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "bedrock.amazonaws.com"
          }
        }
      }
    ]
  })
}

# =============================================================================
# IAM Policy for Client - RESTRICTIVE
# =============================================================================
# Esta policy se puede attachar a usuarios/roles del cliente
# SOLO permite InvokeAgent, NADA más

resource "aws_iam_policy" "client_invoke_only" {
  name        = "${var.project_name}-client-invoke-only"
  description = "Allows client to ONLY invoke the Bedrock Agent - no read access to prompts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowInvokeAgentOnly"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent"
        ]
        Resource = "arn:aws:bedrock:${local.region}:${local.client_account_id}:agent-alias/${aws_bedrockagent_agent.main.agent_id}/*"
      }
    ]
  })

  tags = local.default_tags
}

# =============================================================================
# IAM Policy - EXPLICIT DENY for Client
# =============================================================================
# Esta policy deniega explícitamente cualquier acceso a recursos protegidos
# Se debe attachar a TODOS los usuarios/roles del cliente (excepto deployer)

resource "aws_iam_policy" "client_deny_protected" {
  name        = "${var.project_name}-client-deny-protected"
  description = "Explicitly denies access to protected Bedrock resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyGetAgent"
        Effect = "Deny"
        Action = [
          "bedrock:GetAgent",
          "bedrock:GetAgentVersion",
          "bedrock:GetPrompt",
          "bedrock:ListPrompts",
          "bedrock:GetAgentAlias"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Sid    = "DenySSMAccess"
        Effect = "Deny"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.client_account_id}:parameter/${var.project_name}/*"
      },
      {
        Sid    = "DenyKMSAccess"
        Effect = "Deny"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus"
        ]
        Resource = aws_kms_key.prompt_encryption.arn
      },
      {
        Sid    = "DenyCloudWatchLogsAccess"
        Effect = "Deny"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:GetLogRecord"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.client_account_id}:log-group:/aws/bedrock/${var.project_name}/*"
      }
    ]
  })

  tags = local.default_tags
}

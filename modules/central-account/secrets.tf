# =============================================================================
# KMS Key for Secrets Encryption
# =============================================================================
# Custom KMS key is required for cross-account secret access

resource "aws_kms_key" "secrets" {
  description             = "KMS key for encrypting agent prompts - allows cross-account access"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCentralAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.central_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowClientAccountDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.client_account_id}:root"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "aws:PrincipalArn" = "arn:aws:iam::${var.client_account_id}:role/${var.project_name}-ecs-task"
          }
        }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# =============================================================================
# Secrets Manager for Agent Prompts
# =============================================================================
# Prompts are stored here and fetched by the container at runtime

resource "aws_secretsmanager_secret" "agent_prompts" {
  name        = "${var.project_name}/agent-prompts"
  description = "System prompts for the protected AI agent"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = local.default_tags
}

resource "aws_secretsmanager_secret_version" "agent_prompts" {
  secret_id = aws_secretsmanager_secret.agent_prompts.id
  secret_string = jsonencode({
    system_prompt      = var.system_prompt
    instruction_prompt = var.instruction_prompt
  })
}

# Resource policy - Allow ECS task role from client account to read
resource "aws_secretsmanager_secret_policy" "agent_prompts" {
  secret_arn = aws_secretsmanager_secret.agent_prompts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.client_account_id}:root"
        }
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "aws:PrincipalArn" = "arn:aws:iam::${var.client_account_id}:role/${var.project_name}-ecs-task"
          }
        }
      }
    ]
  })
}

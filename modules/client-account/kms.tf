# =============================================================================
# KMS Key - BLINDADA
# =============================================================================
# Esta key encripta los prompts. El cliente NO tiene acceso a ella.
# Solo la cuenta central y el Bedrock service role pueden decrypt.

resource "aws_kms_key" "prompt_encryption" {
  description             = "KMS key for encrypting Bedrock Agent prompts - Protected"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # CRITICAL: Key policy that locks out the client
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "prompt-encryption-key-policy"
    Statement = [
      {
        Sid    = "AllowCentralAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.central_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowBedrockServiceRoleDecrypt"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.client_account_id
          }
        }
      },
      {
        Sid    = "AllowSSMServiceDecrypt"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.client_account_id}:log-group:/aws/bedrock/${var.project_name}/*"
          }
        }
      },
      {
        Sid    = "AllowDeployerRoleForSetup"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.client_account_id}:role/${var.project_name}-deployer"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      # EXPLICIT DENY for client account root (except deployer role)
      {
        Sid    = "DenyClientAccountAccess"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = local.client_account_id
          }
          StringNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${local.client_account_id}:role/${var.project_name}-deployer",
              "arn:aws:iam::${local.client_account_id}:role/${var.project_name}-bedrock-agent"
            ]
          }
          # Allow AWS services
          "ForAnyValue:StringNotEquals" = {
            "aws:PrincipalServiceName" = [
              "bedrock.amazonaws.com",
              "ssm.amazonaws.com",
              "logs.amazonaws.com"
            ]
          }
        }
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_kms_alias" "prompt_encryption" {
  name          = "alias/${var.project_name}-prompt-encryption"
  target_key_id = aws_kms_key.prompt_encryption.key_id
}

# =============================================================================
# IAM Role for Cross-Account Administration
# =============================================================================
# This role allows the central account to manage resources in the client account
# including: KMS keys, SSM parameters, Bedrock agents, and monitoring

resource "aws_iam_role" "agent_admin" {
  name = "${var.project_name}-agent-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.central_account_id}:root"
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

# Policy for managing resources in client account
resource "aws_iam_role_policy" "agent_admin_policy" {
  name = "${var.project_name}-agent-admin-policy"
  role = aws_iam_role.agent_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeRoleInClientAccount"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = [for account_id in var.client_account_ids : "arn:aws:iam::${account_id}:role/${var.project_name}-deployer"]
      },
      {
        Sid    = "ManageSecretsLocally"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.central_account_id}:secret:${var.project_name}/*"
      }
    ]
  })
}


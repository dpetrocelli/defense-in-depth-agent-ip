# =============================================================================
# ECR Repository for Agent Container
# =============================================================================
# The container image is stored here and pulled by Lambda in client account

resource "aws_ecr_repository" "agent" {
  name                 = "${var.project_name}-agent"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.default_tags
}

# Allow Lambda from client accounts to pull images
# SECURITY:
# - Lambda service principal for function creation/updates
# - Lambda execution roles for runtime image pulls
# - Client admins CANNOT pull the image directly (no ECR access)
# - Client admins CANNOT download Lambda container code (not exposed like zip)
resource "aws_ecr_repository_policy" "agent" {
  repository = aws_ecr_repository.agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountPermission"
        Effect = "Allow"
        Principal = {
          AWS = [for account in var.client_account_ids : "arn:aws:iam::${account}:root"]
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      },
      {
        Sid    = "LambdaECRImageCrossAccountRetrievalPolicy"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Condition = {
          ArnLike = {
            "aws:sourceARN" = [for account in var.client_account_ids : "arn:aws:lambda:*:${account}:function:*"]
          }
        }
      }
    ]
  })
}

# Lifecycle policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "agent" {
  repository = aws_ecr_repository.agent.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

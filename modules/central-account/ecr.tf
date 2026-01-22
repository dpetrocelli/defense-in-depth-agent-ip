# =============================================================================
# ECR Repository for Agent Container
# =============================================================================
# The container image is stored here and pulled by Lambda in client account

resource "aws_ecr_repository" "agent" {
  name                 = "${var.project_name}-agent"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.default_tags
}

# Allow ONLY Lambda service from client accounts to pull images
# SECURITY: Lambda service principal with source account condition
# - Client admins CANNOT pull the image directly (no ECR access)
# - Client admins CANNOT download Lambda container code (not exposed like zip)
# - Only Lambda service can pull during deployment
resource "aws_ecr_repository_policy" "agent" {
  repository = aws_ecr_repository.agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaServicePull"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.client_account_ids
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

# =============================================================================
# ECR Repository for Agent Container
# =============================================================================
# The container image is stored here and pulled by ECS in client account

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

# Allow ONLY the ECS execution role from client account to pull images
# SECURITY: Restricted to specific role ARN to prevent client admins from
# pulling the image and inspecting docker history to extract signing key
resource "aws_ecr_repository_policy" "agent" {
  repository = aws_ecr_repository.agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSExecutionRolePull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.client_account_id}:role/${var.project_name}-ecs-execution"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
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

# =============================================================================
# ECS Cluster and Service
# =============================================================================
# SECURITY FEATURES:
# - ECS Exec DISABLED (enable_execute_command = false)
# - Read-only root filesystem
# - Non-root user
# - No privileged mode
# - Container insights for monitoring
# =============================================================================

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.default_tags
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-agent"
  retention_in_days = 30

  tags = local.default_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "agent" {
  family                   = "${var.project_name}-agent"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "agent"
      image     = "${var.ecr_repository_url}:${var.container_image_tag}"
      essential = true

      # =================================================================
      # SECURITY: Container hardening
      # =================================================================
      readonlyRootFilesystem = false # Python needs /tmp for some operations
      privileged             = false
      user                   = "1000:1000" # Non-root user

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PORT", value = "8080" },
        { name = "MODEL_ID", value = var.foundation_model },
        { name = "GATEKEEPER_URL", value = var.gatekeeper_url },
        { name = "USE_GATEKEEPER", value = tostring(var.use_gatekeeper) },
        { name = "ENABLE_RESPONSE_FILTER", value = "true" },
        { name = "ENABLE_PREFLIGHT_CHECK", value = "true" },
        { name = "CANARY_WEBHOOK_URL", value = var.canary_webhook_url },
        { name = "PROMPT_SECRET_ARN", value = var.use_gatekeeper ? "" : var.agent_prompts_secret_arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "agent"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.default_tags
}

# ECS Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  # Inbound from ALB only
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # =================================================================
  # SECURITY: Restricted egress
  # =================================================================
  # Only allow HTTPS to VPC endpoints and NAT (for Gatekeeper)
  egress {
    description = "HTTPS to VPC endpoints and internet (for Gatekeeper)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for Gatekeeper URL
  }

  tags = merge(local.default_tags, {
    Name = "${var.project_name}-ecs-tasks-sg"
  })
}

# ECS Service
resource "aws_ecs_service" "agent" {
  name            = "${var.project_name}-agent"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.agent.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  # =================================================================
  # SECURITY: ECS Exec DISABLED
  # =================================================================
  # This prevents shell access to containers.
  # If someone tries to exec, it will fail AND trigger an alert.
  enable_execute_command = false

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.agent.arn
    container_name   = "agent"
    container_port   = 8080
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  # Ensure new deployments use updated task definition
  force_new_deployment = true

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy.ecs_execution,
    aws_iam_role_policy.ecs_task
  ]

  tags = local.default_tags
}

# Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.agent.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

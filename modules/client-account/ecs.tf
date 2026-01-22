# =============================================================================
# ECS Cluster and Service for Protected Agent
# =============================================================================
# Uses default VPC for simplicity

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get subnet details to deduplicate by AZ
data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Select one subnet per AZ (first 2 AZs)
locals {
  az_subnet_map = {
    for s in data.aws_subnet.selected : s.availability_zone => s.id...
  }
  unique_az_subnets = [
    for az, subnets in local.az_subnet_map : subnets[0]
  ]
  # Take first 2 subnets from different AZs for ALB
  alb_subnets = slice(local.unique_az_subnets, 0, min(2, length(local.unique_az_subnets)))
}

# =============================================================================
# ECS Cluster
# =============================================================================

resource "aws_ecs_cluster" "agent" {
  name = "${var.project_name}-agent"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.default_tags
}

# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "agent" {
  name              = "/ecs/${var.project_name}-agent"
  retention_in_days = 30

  tags = local.default_tags
}

# =============================================================================
# ECS Task Definition
# =============================================================================

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
      name  = "agent"
      image = "${var.ecr_repository_url}:${var.container_image_tag}"

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PROMPT_SECRET_ARN"
          value = var.use_gatekeeper ? "" : var.agent_prompts_secret_arn
        },
        {
          name  = "MODEL_ID"
          value = var.foundation_model
        },
        {
          name  = "AWS_REGION"
          value = local.region
        },
        {
          name  = "API_KEY"
          value = var.api_key
        },
        {
          name  = "GATEKEEPER_URL"
          value = var.gatekeeper_url
        },
        {
          name  = "USE_GATEKEEPER"
          value = tostring(var.use_gatekeeper)
        },
        {
          name  = "ENABLE_RESPONSE_FILTER"
          value = "true"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.agent.name
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

# =============================================================================
# Security Group for ECS Tasks
# =============================================================================

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

# =============================================================================
# Application Load Balancer
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.default_tags
}

resource "aws_lb" "agent" {
  name               = "${var.project_name}-agent"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.alb_subnets

  tags = local.default_tags
}

resource "aws_lb_target_group" "agent" {
  name        = "${var.project_name}-agent"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = local.default_tags
}

# HTTP listener (for testing - in production use HTTPS)
resource "aws_lb_listener" "agent" {
  load_balancer_arn = aws_lb.agent.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent.arn
  }
}

# =============================================================================
# ECS Service
# =============================================================================

resource "aws_ecs_service" "agent" {
  name            = "${var.project_name}-agent"
  cluster         = aws_ecs_cluster.agent.id
  task_definition = aws_ecs_task_definition.agent.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  # Security: Explicitly disable ECS Exec to prevent shell access to container
  enable_execute_command = false

  network_configuration {
    subnets          = local.alb_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.agent.arn
    container_name   = "agent"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.agent]

  tags = local.default_tags
}

# =============================================================================
# Variables for ECS Client Account Module
# =============================================================================

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "central_account_id" {
  description = "AWS Account ID of the central/admin account"
  type        = string
}

# ECR Repository (from central account)
variable "ecr_repository_url" {
  description = "URL of the ECR repository in central account"
  type        = string
}

variable "container_image_tag" {
  description = "Tag of the container image to deploy"
  type        = string
  default     = "latest"
}

# Secrets (from central account)
variable "agent_prompts_secret_arn" {
  description = "ARN of the Secrets Manager secret containing agent prompts (in central account)"
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the secrets (in central account)"
  type        = string
}

# Model configuration
variable "foundation_model" {
  description = "Foundation model ID for Bedrock"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

# ECS Configuration
variable "ecs_cpu" {
  description = "CPU units for the ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory for the ECS task in MB"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_min_count" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 1
}

variable "ecs_max_count" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 3
}

# Gatekeeper
variable "gatekeeper_url" {
  description = "URL of the Lambda Gatekeeper for secure prompt delivery"
  type        = string
}

variable "use_gatekeeper" {
  description = "Whether to use the Lambda Gatekeeper (true) or direct Secrets Manager access (false)"
  type        = bool
  default     = true
}

# Central account resources for alerts/audit
variable "central_sns_topic_arn" {
  description = "ARN of the SNS topic in central account for security alerts"
  type        = string
}

variable "central_audit_bucket_arn" {
  description = "ARN of the S3 bucket in central account for audit logs"
  type        = string
}

variable "central_audit_bucket_name" {
  description = "Name of the S3 bucket in central account for audit logs"
  type        = string
}

# Security
variable "canary_webhook_url" {
  description = "Webhook URL to notify if canary token is detected in output (prompt leak detection)"
  type        = string
  default     = ""
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services (reduces NAT costs, improves security). Set to false to use NAT Gateway only."
  type        = bool
  default     = false
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# WAF Rate Limiting
variable "waf_rate_limit" {
  description = "Maximum requests per 5 minutes per IP"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

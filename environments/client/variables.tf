variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (optional - can also use AWS_PROFILE env var)"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "bedrock-protected"
}

variable "client_name" {
  description = "Name of the client (for tagging)"
  type        = string
}

variable "central_account_id" {
  description = "AWS Account ID of the central/admin account"
  type        = string
}

# =============================================================================
# Container Configuration (from central account)
# =============================================================================

variable "ecr_repository_url" {
  description = "URL of the ECR repository in central account"
  type        = string
}

variable "container_image_tag" {
  description = "Tag of the container image to deploy"
  type        = string
  default     = "latest"
}

variable "agent_prompts_secret_arn" {
  description = "ARN of the Secrets Manager secret containing agent prompts (in central account)"
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the secrets (in central account)"
  type        = string
}

# =============================================================================
# Model Configuration
# =============================================================================

variable "foundation_model" {
  description = "Foundation model ID (using Nova Lite)"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

# =============================================================================
# ECS Configuration
# =============================================================================

variable "ecs_cpu" {
  description = "CPU units for the ECS task (1024 = 1 vCPU)"
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

# =============================================================================
# Central Account Resources (from central environment outputs)
# =============================================================================

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

# =============================================================================
# API Security
# =============================================================================

variable "api_key" {
  description = "API key for authenticating requests to the agent (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Gatekeeper Configuration (Secure Prompt Delivery)
# =============================================================================

variable "gatekeeper_url" {
  description = "URL of the Lambda Gatekeeper for secure prompt delivery"
  type        = string
  default     = ""
}

variable "use_gatekeeper" {
  description = "Whether to use the Lambda Gatekeeper (true) or direct Secrets Manager access (false)"
  type        = bool
  default     = true
}

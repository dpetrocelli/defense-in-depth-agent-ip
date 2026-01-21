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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

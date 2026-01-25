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

# Lambda Configuration
variable "lambda_memory" {
  description = "Memory for the Lambda function in MB (128-10240)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds (max 900)"
  type        = number
  default     = 60
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

variable "central_event_bus_arn" {
  description = "ARN of the EventBridge Event Bus in central account for cross-account monitoring"
  type        = string
  default     = ""
}

variable "api_key" {
  description = "API key for authenticating requests to the agent (optional - if not set, no auth required)"
  type        = string
  default     = ""
  sensitive   = true
}

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

variable "canary_webhook_url" {
  description = "Webhook URL to notify if canary token is detected in output (prompt leak detection)"
  type        = string
  default     = ""
}

# =============================================================================
# API Gateway Rate Limiting
# =============================================================================

variable "api_rate_limit" {
  description = "Default rate limit for API Gateway (requests per second)"
  type        = number
  default     = 100
}

variable "api_burst_limit" {
  description = "Default burst limit for API Gateway (max concurrent requests)"
  type        = number
  default     = 200
}

variable "invoke_rate_limit" {
  description = "Rate limit for /invoke endpoint (requests per second) - lower to control costs"
  type        = number
  default     = 10
}

variable "invoke_burst_limit" {
  description = "Burst limit for /invoke endpoint (max concurrent requests)"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

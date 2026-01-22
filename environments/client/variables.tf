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
# Lambda Configuration
# =============================================================================

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

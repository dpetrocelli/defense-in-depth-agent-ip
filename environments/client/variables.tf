variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "bedrock-protected"
}

variable "client_name" {
  description = "Name of the client (for tagging)"
  type        = string
  default     = "demo-client"
}

variable "central_account_id" {
  description = "AWS Account ID of the central/admin account"
  type        = string
  default     = "190045319446" # Central account
}

# =============================================================================
# Bedrock Agent Configuration
# =============================================================================

variable "agent_name" {
  description = "Name of the Bedrock Agent"
  type        = string
  default     = "protected-agent"
}

variable "agent_description" {
  description = "Description of the Bedrock Agent"
  type        = string
  default     = "Protected Bedrock Agent with encrypted prompts"
}

variable "foundation_model" {
  description = "Foundation model ID (using Nova Lite)"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

# =============================================================================
# Prompts (SENSITIVE)
# =============================================================================

variable "system_prompt" {
  description = "System prompt for the agent (will be encrypted)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "instruction_prompt" {
  description = "Instruction prompt for the agent (will be encrypted)"
  type        = string
  sensitive   = true
  default     = ""
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

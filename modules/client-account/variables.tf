variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "central_account_id" {
  description = "AWS Account ID of the central/admin account"
  type        = string
}

variable "agent_name" {
  description = "Name of the Bedrock Agent"
  type        = string
}

variable "agent_description" {
  description = "Description of the Bedrock Agent"
  type        = string
  default     = "Protected Bedrock Agent"
}

variable "foundation_model" {
  description = "Foundation model ID for the Bedrock Agent"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "system_prompt" {
  description = "System prompt for the Bedrock Agent (will be encrypted)"
  type        = string
  sensitive   = true
}

variable "instruction_prompt" {
  description = "Instruction prompt for the Bedrock Agent (will be encrypted)"
  type        = string
  sensitive   = true
}

variable "idle_session_ttl_seconds" {
  description = "Idle session TTL in seconds for the agent"
  type        = number
  default     = 600
}

# Central account resources (outputs from central-account module)
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

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "client_account_id" {
  description = "AWS Account ID of the client where the Bedrock Agent will be deployed"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive security alerts"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for security alerts (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "audit_log_retention_days" {
  description = "Number of days to retain audit logs in S3"
  type        = number
  default     = 365
}

variable "system_prompt" {
  description = "System prompt for the AI agent (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "instruction_prompt" {
  description = "Instruction prompt for the AI agent (stored in Secrets Manager)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

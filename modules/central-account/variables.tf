variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "client_account_ids" {
  description = "AWS Account IDs of the clients where the Bedrock Agent will be deployed"
  type        = list(string)
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

variable "gatekeeper_rate_limit" {
  description = "Maximum requests per minute per client account to the gatekeeper"
  type        = number
  default     = 60
}

variable "gatekeeper_throttle_rate" {
  description = "API Gateway throttle rate (requests per second)"
  type        = number
  default     = 10
}

variable "gatekeeper_throttle_burst" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 20
}

variable "gatekeeper_allowed_ips" {
  description = "List of CIDR blocks allowed to access the gatekeeper (empty = allow all)"
  type        = list(string)
  default     = []
}

# =============================================================================
# Budget Alerting
# =============================================================================

variable "monthly_budget_limit" {
  description = "Monthly budget limit for the entire project in USD"
  type        = string
  default     = "100"
}

variable "bedrock_budget_limit" {
  description = "Monthly budget limit for Bedrock usage in USD"
  type        = string
  default     = "50"
}

variable "lambda_budget_limit" {
  description = "Monthly budget limit for Lambda usage in USD"
  type        = string
  default     = "20"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

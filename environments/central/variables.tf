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

variable "client_account_id" {
  description = "AWS Account ID of the client"
  type        = string
}

variable "alert_email" {
  description = "Email for security alerts"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook for security alerts"
  type        = string
  default     = ""
  sensitive   = true
}

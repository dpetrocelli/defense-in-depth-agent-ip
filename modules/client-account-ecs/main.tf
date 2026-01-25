# =============================================================================
# Client Account Module - ECS Fargate Version
# =============================================================================
# Deploys the protected agent on ECS Fargate with maximum security hardening.
#
# SECURITY FEATURES:
# - ECS Exec DISABLED (no shell access to containers)
# - VPC with restricted egress (only Bedrock, Gatekeeper, ECR)
# - WAF on ALB with rate limiting
# - CloudTrail alerts for tampering attempts
# - Permission boundary on task role
# - Pre-flight check blocks startup if Bedrock logging enabled
# - Canary tokens detect prompt leaks
#
# REMAINING RISKS (cannot be technically prevented):
# - Client can enable Bedrock model invocation logging (ALERT only)
# - Client can modify task definition (ALERT only)
# - Client can create sidecar containers (ALERT only)
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region            = data.aws_region.current.name
  client_account_id = data.aws_caller_identity.current.account_id

  default_tags = merge(var.tags, {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Module      = "client-account-ecs"
    Environment = "production"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  central_account_id = data.aws_caller_identity.current.account_id
  region             = data.aws_region.current.name

  default_tags = merge(var.tags, {
    Project   = var.project_name
    ManagedBy = "terraform"
    Module    = "bedrock-protected-mode/central-account"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  client_account_id = data.aws_caller_identity.current.account_id
  region            = data.aws_region.current.id

  default_tags = merge(var.tags, {
    Project   = var.project_name
    ManagedBy = "terraform"
    Module    = "bedrock-protected-mode/client-account"
  })
}

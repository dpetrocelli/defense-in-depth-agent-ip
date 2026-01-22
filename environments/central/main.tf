# =============================================================================
# Central Account Environment
# =============================================================================
# Purpose: Admin account - stores prompts in Secrets Manager, ECR for container images
#
# Before running:
#   export AWS_PROFILE=your-central-account-profile
#   # OR set aws_profile in terraform.tfvars

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # TODO: Configure backend for state storage
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "bedrock-protected-mode/central/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = "central"
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

locals {
  # Load prompts from files
  system_prompt      = file("${path.module}/prompts/system.txt")
  instruction_prompt = file("${path.module}/prompts/instruction.txt")
}

module "central_account" {
  source = "../../modules/central-account"

  project_name       = var.project_name
  client_account_ids = var.client_account_ids
  alert_email        = var.alert_email
  slack_webhook_url  = var.slack_webhook_url

  # Prompts (stored in Secrets Manager, fetched by container at runtime)
  system_prompt      = local.system_prompt
  instruction_prompt = local.instruction_prompt

  tags = {
    Environment = "central"
  }
}

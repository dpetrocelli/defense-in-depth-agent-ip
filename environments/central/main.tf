# =============================================================================
# Central Account Environment
# =============================================================================
# Account: 190045319446 (AdministratorAccess-190045319446)
# Purpose: Admin account - manages agents, receives alerts, stores audit logs

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
  profile = "AdministratorAccess-190045319446"

  default_tags {
    tags = {
      Environment = "central"
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

module "central_account" {
  source = "../../modules/central-account"

  project_name      = var.project_name
  client_account_id = var.client_account_id
  alert_email       = var.alert_email
  slack_webhook_url = var.slack_webhook_url

  tags = {
    Environment = "central"
  }
}

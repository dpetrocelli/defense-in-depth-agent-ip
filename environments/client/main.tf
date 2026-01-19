# =============================================================================
# Client Account Environment
# =============================================================================
# Account: 875228160179 (AdministratorAccess-875228160179)
# Purpose: Client account - hosts the Bedrock Agent, client uses but cannot see prompts

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
  #   key            = "bedrock-protected-mode/client/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region  = var.region
  profile = "AdministratorAccess-875228160179"

  default_tags {
    tags = {
      Environment = "client"
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

module "client_account" {
  source = "../../modules/client-account"

  project_name       = var.project_name
  central_account_id = var.central_account_id

  # Bedrock Agent config
  agent_name         = var.agent_name
  agent_description  = var.agent_description
  foundation_model   = var.foundation_model

  # Prompts (sensitive - will be encrypted)
  system_prompt      = var.system_prompt
  instruction_prompt = var.instruction_prompt

  # Central account resources (from central environment outputs)
  central_sns_topic_arn     = var.central_sns_topic_arn
  central_audit_bucket_arn  = var.central_audit_bucket_arn
  central_audit_bucket_name = var.central_audit_bucket_name

  tags = {
    Environment = "client"
    ClientName  = var.client_name
  }
}

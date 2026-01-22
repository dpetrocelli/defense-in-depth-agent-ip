# =============================================================================
# Client Account Environment
# =============================================================================
# Purpose: Client account - hosts Lambda + API Gateway running the Strands agent
#
# Before running:
#   export AWS_PROFILE=your-client-account-profile
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
  #   key            = "bedrock-protected-mode/client/terraform.tfstate"
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

  # Container image (from central account ECR)
  ecr_repository_url  = var.ecr_repository_url
  container_image_tag = var.container_image_tag

  # Prompts secret (from central account Secrets Manager)
  agent_prompts_secret_arn = var.agent_prompts_secret_arn
  secrets_kms_key_arn      = var.secrets_kms_key_arn

  # Model configuration
  foundation_model = var.foundation_model

  # Lambda configuration
  lambda_memory  = var.lambda_memory
  lambda_timeout = var.lambda_timeout

  # Central account resources (from central environment outputs)
  central_sns_topic_arn     = var.central_sns_topic_arn
  central_audit_bucket_arn  = var.central_audit_bucket_arn
  central_audit_bucket_name = var.central_audit_bucket_name

  # API Security
  api_key = var.api_key

  # Gatekeeper (secure prompt delivery)
  gatekeeper_url = var.gatekeeper_url
  use_gatekeeper = var.use_gatekeeper

  tags = {
    Environment = "client"
    ClientName  = var.client_name
  }
}

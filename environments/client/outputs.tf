output "client_account_id" {
  description = "Client account ID"
  value       = module.client_account.client_account_id
}

output "agent_id" {
  description = "Bedrock Agent ID"
  value       = module.client_account.agent_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN"
  value       = module.client_account.agent_arn
}

output "agent_alias_id" {
  description = "Bedrock Agent Alias ID"
  value       = module.client_account.agent_alias_id
}

output "agent_alias_arn" {
  description = "Bedrock Agent Alias ARN"
  value       = module.client_account.agent_alias_arn
}

output "invoke_agent_command" {
  description = "AWS CLI command to invoke the agent"
  value       = module.client_account.invoke_agent_command
}

# Policies to attach to client users/roles
output "client_policies" {
  description = "IAM policies to attach to client users/roles"
  value = {
    invoke_only = module.client_account.client_invoke_policy_arn
    deny_access = module.client_account.client_deny_policy_arn
  }
}

# Security information
output "security_info" {
  description = "Security-related outputs"
  value = {
    kms_key_arn          = module.client_account.kms_key_arn
    deployer_role_arn    = module.client_account.deployer_role_arn
    bedrock_agent_role   = module.client_account.bedrock_agent_role_arn
  }
}

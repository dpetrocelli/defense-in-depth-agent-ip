output "client_account_id" {
  description = "Client account ID"
  value       = local.client_account_id
}

output "agent_id" {
  description = "Bedrock Agent ID"
  value       = aws_bedrockagent_agent.main.agent_id
}

output "agent_arn" {
  description = "Bedrock Agent ARN"
  value       = aws_bedrockagent_agent.main.agent_arn
}

output "agent_alias_id" {
  description = "Bedrock Agent Alias ID"
  value       = aws_bedrockagent_agent_alias.main.agent_alias_id
}

output "agent_alias_arn" {
  description = "Bedrock Agent Alias ARN"
  value       = aws_bedrockagent_agent_alias.main.agent_alias_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for prompt encryption"
  value       = aws_kms_key.prompt_encryption.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for prompt encryption"
  value       = aws_kms_key.prompt_encryption.key_id
}

output "deployer_role_arn" {
  description = "ARN of the deployer role (for central account to assume)"
  value       = aws_iam_role.deployer.arn
}

output "bedrock_agent_role_arn" {
  description = "ARN of the Bedrock Agent execution role"
  value       = aws_iam_role.bedrock_agent.arn
}

output "client_invoke_policy_arn" {
  description = "ARN of the IAM policy that allows client to invoke the agent"
  value       = aws_iam_policy.client_invoke_only.arn
}

output "client_deny_policy_arn" {
  description = "ARN of the IAM policy that denies client access to protected resources"
  value       = aws_iam_policy.client_deny_protected.arn
}

output "invoke_agent_command" {
  description = "AWS CLI command to invoke the agent"
  value       = "aws bedrock-agent-runtime invoke-agent --agent-id ${aws_bedrockagent_agent.main.agent_id} --agent-alias-id ${aws_bedrockagent_agent_alias.main.agent_alias_id} --session-id SESSION_ID --input-text 'YOUR_MESSAGE'"
}

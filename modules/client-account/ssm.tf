# =============================================================================
# SSM Parameters - Prompts Encriptados
# =============================================================================
# Los prompts se guardan como SecureString encriptados con la KMS key.
# El cliente NO puede leerlos.

resource "aws_ssm_parameter" "system_prompt" {
  name        = "/${var.project_name}/bedrock/system-prompt"
  description = "System prompt for Bedrock Agent - PROTECTED"
  type        = "SecureString"
  value       = var.system_prompt
  key_id      = aws_kms_key.prompt_encryption.arn

  tags = local.default_tags
}

resource "aws_ssm_parameter" "instruction_prompt" {
  name        = "/${var.project_name}/bedrock/instruction-prompt"
  description = "Instruction prompt for Bedrock Agent - PROTECTED"
  type        = "SecureString"
  value       = var.instruction_prompt
  key_id      = aws_kms_key.prompt_encryption.arn

  tags = local.default_tags
}

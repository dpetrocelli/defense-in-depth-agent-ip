# =============================================================================
# Bedrock Agent
# =============================================================================
# El agente usa Nova Lite y tiene logging deshabilitado o encriptado

resource "aws_bedrockagent_agent" "main" {
  agent_name              = var.agent_name
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  description             = var.agent_description
  foundation_model        = var.foundation_model
  idle_session_ttl_in_seconds = var.idle_session_ttl_seconds

  # Use the instruction prompt from SSM (decrypted by Bedrock service role)
  instruction = var.instruction_prompt

  tags = local.default_tags
}

# Prepare the agent after creation
resource "aws_bedrockagent_agent_action_group" "allow_invoke" {
  count = 0 # Placeholder - add action groups as needed

  agent_id          = aws_bedrockagent_agent.main.agent_id
  agent_version     = "DRAFT"
  action_group_name = "placeholder"

  action_group_executor {
    lambda = "placeholder"
  }

  skip_resource_in_use_check = true
}

# Agent Alias for stable endpoint
resource "aws_bedrockagent_agent_alias" "main" {
  agent_alias_name = "production"
  agent_id         = aws_bedrockagent_agent.main.agent_id
  description      = "Production alias for ${var.agent_name}"

  tags = local.default_tags
}

# Deployment Guide

## Prerequisites

1. AWS CLI configured with SSO profiles:
   - `AdministratorAccess-190045319446` (Central account)
   - `AdministratorAccess-875228160179` (Client account)

2. Terraform >= 1.0 installed

3. AWS SSO login for both accounts:
   ```bash
   aws sso login --profile AdministratorAccess-190045319446
   aws sso login --profile AdministratorAccess-875228160179
   ```

## Deployment Order

**IMPORTANT:** The central account MUST be deployed first because the client account depends on its outputs.

### Step 1: Deploy Central Account

```bash
cd environments/central

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

Save the outputs - you'll need them for the client environment:
```bash
terraform output for_client_environment
```

### Step 2: Deploy Client Account

```bash
cd environments/client

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Set up prompts (choose one method):

# Method A: Environment variables (recommended for CI/CD)
export TF_VAR_system_prompt="Your system prompt here"
export TF_VAR_instruction_prompt="Your instruction prompt here"

# Method B: Prompt files (recommended for local dev)
cp prompts/system.txt.example prompts/system.txt
cp prompts/instruction.txt.example prompts/instruction.txt
# Edit the files with your actual prompts

# Then in terraform.tfvars:
# system_prompt      = file("prompts/system.txt")
# instruction_prompt = file("prompts/instruction.txt")

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

### Step 3: Configure Client User Permissions

After deployment, attach the IAM policies to client users/roles:

```bash
# Get policy ARNs from outputs
terraform output client_policies

# Attach to a client user/role
aws iam attach-user-policy \
  --user-name CLIENT_USER \
  --policy-arn "arn:aws:iam::875228160179:policy/bedrock-protected-client-invoke-only" \
  --profile AdministratorAccess-875228160179

aws iam attach-user-policy \
  --user-name CLIENT_USER \
  --policy-arn "arn:aws:iam::875228160179:policy/bedrock-protected-client-deny-protected" \
  --profile AdministratorAccess-875228160179
```

## Testing the Agent

### Test Invocation (as permitted user)

```bash
# Get the invoke command from outputs
terraform output invoke_agent_command

# Or manually:
aws bedrock-agent-runtime invoke-agent \
  --agent-id AGENT_ID \
  --agent-alias-id ALIAS_ID \
  --session-id "test-session-001" \
  --input-text "Hello, how can you help me?" \
  --profile AdministratorAccess-875228160179
```

### Test Security (should fail)

These commands should return "Access Denied":

```bash
# Try to read the agent config
aws bedrock-agent get-agent \
  --agent-id AGENT_ID \
  --profile AdministratorAccess-875228160179

# Try to read SSM parameter
aws ssm get-parameter \
  --name "/bedrock-protected/bedrock/system-prompt" \
  --with-decryption \
  --profile AdministratorAccess-875228160179

# Try to decrypt with KMS
aws kms decrypt \
  --key-id alias/bedrock-protected-prompt-encryption \
  --ciphertext-blob fileb://... \
  --profile AdministratorAccess-875228160179
```

## Updating Prompts

To update prompts after initial deployment:

```bash
cd environments/client

# Update your prompt files or environment variables
# Then:
terraform apply -target=module.client_account.aws_ssm_parameter.system_prompt
terraform apply -target=module.client_account.aws_ssm_parameter.instruction_prompt
```

## Destroying Resources

**WARNING:** This will delete all resources including the agent and audit logs.

```bash
# First destroy client account
cd environments/client
terraform destroy

# Then destroy central account
cd environments/central
terraform destroy
```

## Troubleshooting

### SSO Token Expired
```bash
aws sso login --profile AdministratorAccess-190045319446
aws sso login --profile AdministratorAccess-875228160179
```

### KMS Key Policy Issues
If you get KMS access denied errors during deployment, ensure the deployer role exists first:
```bash
terraform apply -target=module.client_account.aws_iam_role.deployer
```

### EventBridge Not Sending Alerts
1. Check CloudTrail is enabled and logging
2. Verify SNS topic policy allows cross-account publish
3. Check EventBridge rule patterns match actual events

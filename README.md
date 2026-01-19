# Bedrock Protected Mode

Terraform module to deploy **Amazon Bedrock Agents** in customer accounts with full intellectual property protection (prompts, instructions, logic).

## The Problem

When you deploy a Bedrock Agent in a customer's account:
- **Customer data must stay in their account** (compliance, security)
- **Your prompts are intellectual property** that you don't want to expose
- The customer with admin/root access could technically see everything

## The Solution: "Paranoid Mode" Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Customer Account                           │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  KMS Key (yours)                                          │ │
│  │  - Customer: ❌ NOTHING                                   │ │
│  │  - Your account: ✅ Full access                           │ │
│  │  - Bedrock service role: ✅ Decrypt only                  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  SSM Parameter (prompt encrypted with KMS)                │ │
│  │  - Customer: ❌ ssm:GetParameter DENIED                   │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Bedrock Agent                                            │ │
│  │  - Customer: ✅ InvokeAgent ONLY                          │ │
│  │  - Customer: ❌ GetAgent, UpdateAgent, etc.               │ │
│  │  - Logging: DISABLED or encrypted with your KMS           │ │
│  │  - Tracing: DISABLED                                      │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  CloudWatch Logs (if they exist)                          │ │
│  │  - Encrypted with your KMS                                │ │
│  │  - Customer: ❌ logs:GetLogEvents DENIED                  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  CloudTrail → EventBridge → SNS (to your account)         │ │
│  │                                                           │ │
│  │  Alerts if customer attempts:                             │ │
│  │  - kms:PutKeyPolicy                                       │ │
│  │  - iam:* on Bedrock roles                                 │ │
│  │  - ssm:GetParameter on /bedrock/*                         │ │
│  │  - bedrock:GetAgent                                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  SCP (if you use Organizations)                           │ │
│  │                                                           │ │
│  │  Deny:                                                    │ │
│  │  - kms:* on your KMS key ARN                              │ │
│  │  - iam:* on roles you created                             │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
         Cross-Account Access │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Your Account                             │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────────────────────┐    │
│  │  IAM Role       │    │  CI/CD Pipeline                 │    │
│  │  "AgentAdmin"   │    │                                 │    │
│  │                 │    │  - Updates prompts              │    │
│  │  Can:           │    │  - Deploys new versions         │    │
│  │  - ssm:Put*     │    │  - Rotates KMS keys if needed   │    │
│  │  - kms:*        │    │                                 │    │
│  │  - bedrock:*    │    └─────────────────────────────────┘    │
│  └─────────────────┘                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Protection Layers

### 1. KMS Key with Hardened Policy
- The customer has NO permissions on the key
- Only your account (cross-account) and the Bedrock service role can decrypt
- Impossible to modify without your authorization

### 2. Encrypted SSM Parameters
- Prompts are stored as `SecureString`
- Encrypted with your KMS key
- Resource policy that denies customer access

### 3. Explicit IAM Deny
- The customer can ONLY use `bedrock:InvokeAgent`
- Explicit DENY on:
  - `bedrock:GetAgent`
  - `bedrock:GetPrompt`
  - `ssm:GetParameter` (for `/bedrock/*`)
  - `kms:Decrypt`

### 4. Protected Logging
- CloudWatch Logs disabled OR encrypted with your KMS
- X-Ray/Tracing disabled
- Customer cannot see execution logs

### 5. Monitoring and Alerts
- CloudTrail captures ALL access attempts
- EventBridge rules detect suspicious actions
- SNS notifies YOUR account in real-time
- Evidence saved for legal actions

### 6. SCP (Optional - AWS Organizations)
- Blocks modifications at the organization level
- Not even root can modify your resources

## Security Level

| Scenario | Can they see the prompt? | Notes |
|----------|-------------------------|-------|
| Normal customer using the agent | ❌ No | Can only invoke |
| Curious customer in the console | ❌ No | Access Denied |
| Customer with IAM Admin | ❌ No | KMS key policy blocks them |
| Customer with Root + modifies KMS policy | ⚠️ Yes | But you'll know via alerts |
| Customer with Root + SCP active | ❌ No | SCP blocks them |

## Alerts You Receive

When the customer attempts to access protected resources:

```
🚨 ALERT: Unauthorized access attempt

Account: 123456789012 (Customer XYZ)
Time: 2024-01-15 14:32:15 UTC
User: arn:aws:iam::123456789012:user/admin
Action: ssm:GetParameter
Resource: /bedrock/agent/system-prompt
Result: ACCESS DENIED

────────────────────────────────────
This evidence has been saved to:
s3://your-bucket/audit-logs/2024/01/15/...

Contract: Section 5.2 - Reverse engineering
          prohibition
────────────────────────────────────
```

## Module Structure

```
bedrock-protected-mode/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── kms.tf                 # KMS Key with hardened policy
├── ssm.tf                 # Encrypted prompts
├── bedrock.tf             # Agent + Alias
├── iam.tf                 # Restrictive roles and policies
├── monitoring.tf          # CloudTrail + EventBridge + SNS
├── scp.tf                 # Service Control Policy (optional)
├── examples/
│   └── complete/
│       ├── main.tf
│       └── terraform.tfvars.example
└── docs/
    ├── SECURITY.md        # Documentation for the customer
    └── CONTRACT_TEMPLATE.md # Template for legal clauses
```

## Usage

```hcl
module "bedrock_protected" {
  source = "github.com/dpetrocelli/bedrock-protected-mode"

  # Your account (for cross-account access)
  admin_account_id = "111111111111"

  # Customer account
  client_account_id = "222222222222"

  # Agent configuration
  agent_name        = "my-protected-agent"
  foundation_model  = "anthropic.claude-3-sonnet-20240229-v1:0"

  # Prompts (automatically encrypted)
  system_prompt     = file("prompts/system.txt")
  instruction       = file("prompts/instruction.txt")

  # Alerts
  alert_email       = "security@yourcompany.com"
  slack_webhook_url = "https://hooks.slack.com/..."

  # Tags
  tags = {
    Client      = "CustomerXYZ"
    Environment = "production"
  }
}
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- Customer's AWS account with deployment permissions
- Your AWS account with IAM role for cross-account access

## Legal Considerations

This module provides **technical** protection. For complete protection, combine with:

1. **Service contract** with clauses for:
   - Reverse engineering prohibition
   - Prohibition of access to protected components
   - Penalties for non-compliance

2. **NDA** specific to intellectual property

3. **Audit documentation** that demonstrates unauthorized access attempts

See [docs/CONTRACT_TEMPLATE.md](docs/CONTRACT_TEMPLATE.md) for templates.

## License

Proprietary - All rights reserved.

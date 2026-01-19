# CLAUDE.md - Bedrock Protected Mode

## Project

Terraform module to deploy **Amazon Bedrock Agents** in customer accounts with full intellectual property protection (prompts, instructions).

## The Problem to Solve

- The Bedrock Agent MUST live in the customer's account (their data cannot leave)
- The prompts are our intellectual property that we DO NOT want to expose
- We need the customer to be able to USE the agent but NOT see the prompts

## Multi-Account Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  CLIENT ACCOUNT: 875228160179                                   │
│  Profile: AdministratorAccess-875228160179                      │
│                                                                 │
│  Lives here:                                                    │
│  - Bedrock Agent (Nova Lite)                                   │
│  - SSM Parameters (prompts encrypted with KMS)                 │
│  - KMS Key (controlled by central account)                     │
│  - CloudTrail + EventBridge (alerts to central account)        │
│  - Restrictive IAM Policies                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Cross-Account Trust
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  CENTRAL ACCOUNT (ADMIN): 190045319446                         │
│  Profile: AdministratorAccess-190045319446                      │
│                                                                 │
│  Lives here:                                                    │
│  - IAM Role "AgentAdmin" (to manage the agent)                 │
│  - S3 Bucket for audit logs (legal evidence)                   │
│  - SNS Topic (receives alerts from client account)             │
│  - Secrets Manager (source of truth for prompts)               │
└─────────────────────────────────────────────────────────────────┘
```

## Security Layers (Paranoid Mode)

1. **Hardened KMS Key**: The client has NO permissions, only central account + Bedrock service
2. **SSM SecureString**: Encrypted prompts, client cannot read
3. **Explicit IAM Deny**: Client can only `InvokeAgent`, everything else is denied
4. **CloudTrail + EventBridge**: Detects any unauthorized access attempt
5. **SNS Alerts**: Notifies central account in real-time
6. **S3 Audit Logs**: Legal evidence for the contract

## Repo Structure

```
bedrock-protected-mode/
├── modules/
│   ├── central-account/      # Deploy to 190045319446
│   │   ├── iam.tf            # Cross-account role
│   │   ├── s3.tf             # Audit bucket
│   │   └── sns.tf            # Alerts
│   │
│   └── client-account/       # Deploy to 875228160179
│       ├── kms.tf            # Hardened KMS
│       ├── ssm.tf            # Encrypted prompts
│       ├── bedrock.tf        # Agent (Nova Lite)
│       ├── iam.tf            # Restrictive policies
│       └── monitoring.tf     # CloudTrail + EventBridge
│
├── environments/
│   ├── central/              # Parent for 190045319446
│   └── client/               # Parent for 875228160179
│
└── docs/
    ├── DEPLOYMENT.md         # Deployment guide
    ├── SECURITY.md           # Security architecture
    └── CONTRACT_TEMPLATE.md  # Legal clauses
```

## Deployment Order

1. **First central account** (190045319446):
   ```bash
   cd environments/central
   aws sso login --profile AdministratorAccess-190045319446
   terraform init && terraform apply
   ```

2. **Then client account** (875228160179):
   ```bash
   cd environments/client
   aws sso login --profile AdministratorAccess-875228160179
   terraform init && terraform apply
   ```

## Foundation Model

We use **Amazon Nova Lite** (`amazon.nova-lite-v1:0`) - no special enablement required.

## Pending / TODOs

- [ ] Deploy and test in both accounts
- [ ] Validate that the agent works with Nova Lite
- [ ] Verify that alerts arrive correctly
- [ ] Test the deny policies (try to read prompts as client)
- [ ] Add Action Groups if needed (Lambda integrations)
- [ ] Consider Knowledge Bases for RAG

## Git

- Do not include "Co-Authored-By" in commits
- Real prompts go in `environments/client/prompts/` (gitignored)
- Secrets go in `terraform.tfvars` (gitignored)

## Useful Commands

```bash
# SSO Login
aws sso login --profile AdministratorAccess-190045319446
aws sso login --profile AdministratorAccess-875228160179

# Invoke the agent (after deploy)
aws bedrock-agent-runtime invoke-agent \
  --agent-id AGENT_ID \
  --agent-alias-id ALIAS_ID \
  --session-id "test-001" \
  --input-text "Hello" \
  --profile AdministratorAccess-875228160179

# Test that the client CANNOT read prompts (should fail)
aws ssm get-parameter \
  --name "/bedrock-protected/bedrock/system-prompt" \
  --with-decryption \
  --profile AdministratorAccess-875228160179
```

# Bedrock Protected Mode - Architecture Documentation

## Executive Summary

This document describes the architecture of **Bedrock Protected Mode**, a Terraform solution that enables deploying Amazon Bedrock Agents in customer accounts while maintaining complete protection of intellectual property (prompts, instructions, and logic).

### The Business Problem

When deploying AI agents for customers:
- **Customer data sovereignty**: Data must remain in the customer's AWS account
- **IP protection**: Your prompts and logic are valuable intellectual property
- **Trust but verify**: Customers with admin access could potentially extract your IP

### The Solution

A **multi-account architecture** with **6 layers of defense-in-depth security** that ensures:
- Customers can **USE** the agent normally
- Customers **CANNOT** read prompts or agent configuration
- All access attempts are **DETECTED** and **LOGGED**
- Evidence is preserved for **LEGAL** action if needed

---

## Architecture Diagrams

All diagrams are located in the `generated-diagrams/` folder:

| Diagram | Description | Audience |
|---------|-------------|----------|
| [bedrock-protected-mode-architecture.png](../generated-diagrams/bedrock-protected-mode-architecture.png) | Complete multi-account architecture | CTO, Architects |
| [security-layers-defense-in-depth.png](../generated-diagrams/security-layers-defense-in-depth.png) | 6-layer security model | CISO, Security Team |
| [data-flow-normal-vs-attack.png](../generated-diagrams/data-flow-normal-vs-attack.png) | Normal operation vs attack scenarios | Technical Leadership |
| [cross-account-deployment-flow.png](../generated-diagrams/cross-account-deployment-flow.png) | CI/CD and deployment process | DevOps, Engineers |
| [monitoring-incident-response-flow.png](../generated-diagrams/monitoring-incident-response-flow.png) | Alerting and incident response | Security Operations |
| [aws-services-inventory.png](../generated-diagrams/aws-services-inventory.png) | Complete AWS services list | Cloud Architects |

---

## Multi-Account Structure

```
┌─────────────────────────────────────────────────────────────┐
│  CENTRAL ACCOUNT (Your Organization)                        │
│  Account ID: 190045319446                                   │
│                                                             │
│  Purpose: Administration, Monitoring, Evidence Storage      │
│                                                             │
│  Resources:                                                 │
│  - Secrets Manager (prompt source of truth)                │
│  - IAM Agent Admin Role                                    │
│  - SNS Security Alerts Topic                               │
│  - Lambda Slack Notifier                                   │
│  - S3 Audit Logs Bucket                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                   Cross-Account Trust
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  CLIENT ACCOUNT (Customer Environment)                      │
│  Account ID: 875228160179                                   │
│                                                             │
│  Purpose: Agent Execution, User Interaction                 │
│                                                             │
│  Resources:                                                 │
│  - Amazon Bedrock Agent + Alias                            │
│  - KMS Key (hardened policy)                               │
│  - SSM Parameters (encrypted prompts)                      │
│  - IAM Roles & Policies                                    │
│  - CloudTrail + EventBridge (monitoring)                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Security Layers (Defense in Depth)

### Layer 1: IAM Explicit Deny Policies
- **What**: IAM policies attached to all client users/roles
- **Protection**: Explicitly denies `GetAgent`, `GetPrompt`, `GetParameter`, `Decrypt`
- **Bypass difficulty**: Cannot be bypassed by IAM Admin (explicit deny always wins)

### Layer 2: KMS Key Policy (Cryptographic Boundary)
- **What**: Customer Managed Key with hardened policy
- **Protection**:
  - Client account: **NO PERMISSIONS**
  - Central account: Full access
  - Bedrock service: Decrypt only
- **Bypass difficulty**: Requires root account to modify key policy

### Layer 3: SSM SecureString Encryption
- **What**: Prompts stored as encrypted SecureString parameters
- **Protection**: Even if metadata is visible, values are encrypted
- **Bypass difficulty**: Cannot decrypt without KMS key access

### Layer 4: CloudTrail Audit Logging
- **What**: Comprehensive API call logging
- **Protection**: Every access attempt is recorded with full details
- **Coverage**: SSM, KMS, Bedrock, IAM operations

### Layer 5: EventBridge Real-time Detection
- **What**: 4 detection rules monitoring for suspicious activity
- **Alerts on**:
  - SSM parameter access attempts (HIGH severity)
  - KMS key access attempts (CRITICAL severity)
  - Bedrock configuration access (HIGH severity)
  - IAM role modifications (CRITICAL severity)
- **Response time**: Immediate notification via SNS

### Layer 6: S3 Audit Evidence Storage
- **What**: Long-term storage of CloudTrail logs
- **Features**:
  - Versioning enabled (tamper-proof)
  - KMS encryption
  - Lifecycle: Standard → Infrequent Access (90d) → Glacier (180d)
  - Retention: 365 days (configurable)
- **Purpose**: Legal evidence for contract enforcement

---

## Security Matrix

| Scenario | Access Blocked? | Detected? | Evidence Saved? |
|----------|-----------------|-----------|-----------------|
| Normal user invokes agent | N/A (allowed) | No | No |
| User tries to read prompts | ✅ Yes | ✅ Yes | ✅ Yes |
| IAM Admin tries to read prompts | ✅ Yes | ✅ Yes | ✅ Yes |
| IAM Admin modifies IAM roles | ✅ Yes | ✅ Yes (CRITICAL) | ✅ Yes |
| Root modifies KMS policy | ⚠️ Possible | ✅ Yes (CRITICAL) | ✅ Yes |
| Root + SCP enabled | ✅ Yes | ✅ Yes | ✅ Yes |

---

## AWS Services Used

### Client Account (11 Resources)

| Service | Resource | Purpose |
|---------|----------|---------|
| Amazon Bedrock | Agent | AI agent execution |
| Amazon Bedrock | Agent Alias | Stable invocation endpoint |
| AWS KMS | Customer Managed Key | Prompt encryption |
| AWS SSM | Parameter (System Prompt) | Encrypted prompt storage |
| AWS SSM | Parameter (Instruction) | Encrypted prompt storage |
| AWS IAM | Bedrock Agent Role | Service execution permissions |
| AWS IAM | Deployer Role | Cross-account deployment |
| AWS IAM | EventBridge Role | Alert publishing |
| AWS CloudTrail | Trail | API audit logging |
| Amazon EventBridge | 4 Rules | Real-time detection |

### Central Account (6 Resources)

| Service | Resource | Purpose |
|---------|----------|---------|
| AWS Secrets Manager | 2 Secrets | Prompt source of truth |
| AWS IAM | Agent Admin Role | Cross-account administration |
| Amazon SNS | Topic | Alert aggregation |
| AWS Lambda | Slack Notifier | Slack integration |
| Amazon S3 | Audit Bucket | Evidence storage |
| S3 Glacier | Archive | Long-term retention |

---

## Deployment Process

1. **Deploy Central Account** (one-time setup)
   ```bash
   cd environments/central
   terraform init && terraform apply
   ```

2. **Deploy Client Account** (per customer)
   ```bash
   cd environments/client
   terraform init && terraform apply
   ```

3. **Update Prompts** (ongoing)
   - Update secrets in Secrets Manager
   - Run deployment pipeline
   - Deployer role updates SSM parameters

---

## Cost Considerations

### Client Account (Monthly Estimate)
- Bedrock Agent: Pay per invocation (~$0.001-0.01 per request)
- KMS: $1/month + $0.03 per 10,000 requests
- SSM Parameters: Free (standard tier)
- CloudTrail: Free (management events) + S3 storage costs
- EventBridge: $1 per million events

### Central Account (Monthly Estimate)
- Secrets Manager: $0.40 per secret + $0.05 per 10,000 API calls
- SNS: $0.50 per million notifications
- Lambda: Free tier (likely sufficient)
- S3: ~$0.023/GB (Standard) → $0.004/GB (Glacier)

**Estimated Total**: $5-20/month per customer (excluding Bedrock usage)

---

## Legal Integration

This technical solution should be combined with:

1. **Service Agreement** with clauses for:
   - Prohibition of reverse engineering
   - Prohibition of accessing protected components
   - Penalties for violations

2. **NDA** covering intellectual property

3. **Audit Rights** allowing evidence review

See [CONTRACT_TEMPLATE.md](CONTRACT_TEMPLATE.md) for legal clause templates.

---

## Contact

For questions about this architecture, contact your solution architect.

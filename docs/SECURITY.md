# Security Architecture

## Overview

This module implements a "defense in depth" approach to protect intellectual property (prompts, instructions) when deploying Bedrock Agents in client AWS accounts.

## Threat Model

| Threat | Mitigation |
|--------|------------|
| Client reads prompts via Console | IAM Deny policies |
| Client reads prompts via CLI/SDK | IAM Deny policies |
| Client decrypts SSM parameters | KMS key policy denies access |
| Client modifies KMS key policy | Alerting + SCP (optional) |
| Client reads CloudWatch logs | Logs encrypted with protected KMS |
| Client modifies IAM roles | Alerting + SCP (optional) |
| Client with root access | Alerting + Legal contract |

## Security Layers

### Layer 1: KMS Key Policy (Strongest Protection)

The KMS key used to encrypt prompts has a policy that:
- **ALLOWS** central account full access
- **ALLOWS** Bedrock service role decrypt only
- **DENIES** all other principals in client account

```
Client Account Root → KMS Key → ACCESS DENIED
Central Account    → KMS Key → ALLOWED
Bedrock Service    → KMS Key → ALLOWED (decrypt only)
```

### Layer 2: IAM Deny Policies

Explicit deny policies block:
- `bedrock:GetAgent`
- `bedrock:GetPrompt`
- `ssm:GetParameter` (for protected paths)
- `kms:Decrypt` (for protected key)
- `logs:GetLogEvents` (for agent logs)

### Layer 3: SSM Resource Policy

SSM parameters have resource policies that deny access to non-approved principals.

### Layer 4: Monitoring & Alerting

All access attempts are:
1. Logged to CloudTrail
2. Detected by EventBridge rules
3. Sent to central account SNS
4. Stored in S3 for legal evidence

### Layer 5: Service Control Policy (Optional)

If using AWS Organizations, SCPs can prevent:
- Modification of KMS key policies
- Modification of IAM roles created by this module
- Deletion of CloudTrail

## What the Client CAN Do

- `bedrock:InvokeAgent` - Use the agent normally
- View agent exists in console (but not its configuration)
- See that SSM parameters exist (but not read values)
- See that KMS key exists (but not use it)

## What the Client CANNOT Do

- Read agent instructions or prompts
- Decrypt SSM parameters
- Read CloudWatch logs (if encrypted)
- Modify protected IAM roles
- Use the KMS key for any operation

## What the Client COULD Do (with root access)

With root/admin access, a determined client could theoretically:
1. Modify KMS key policy to grant themselves access
2. Then decrypt SSM parameters

**BUT:**
- This would trigger immediate alerts
- All actions are logged as legal evidence
- Violates service agreement (legal consequences)

## Evidence Collection

For legal purposes, the following is automatically collected:
- CloudTrail logs of all API calls
- EventBridge event history
- S3 audit logs (versioned, encrypted)
- SNS notification history

## Recommendations

1. **Always** deploy central account resources first
2. **Always** configure at least one alert destination (email or Slack)
3. **Include** IP protection clauses in client contracts
4. **Consider** using AWS Organizations with SCPs for additional protection
5. **Regularly** review CloudTrail logs and alerts
6. **Rotate** prompts/instructions if you suspect compromise

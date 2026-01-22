# Bedrock Protected Mode

Deploy AI agents in customer AWS accounts while keeping your prompts (intellectual property) completely protected.

## Problem

- AI Agent MUST run in customer's account (data residency)
- Prompts are IP that must NOT be exposed
- Native Bedrock Agents expose prompts in AWS Console

## Solution

```
┌─────────────────────────────────────────────────────────────────┐
│  YOUR ACCOUNT (Central)                                        │
│  ✓ Prompts in Secrets Manager (KMS encrypted)                  │
│  ✓ Container image in ECR                                       │
│  ✓ Audit logs in S3, alerts via SNS                            │
└─────────────────────────────────────────────────────────────────┘
                              │ Only Lambda can pull image
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  CLIENT ACCOUNT                                                 │
│  ✓ Lambda + API Gateway (scales to 0)                          │
│  ✓ CloudTrail + EventBridge (tampering detection)              │
│  ✗ Cannot read prompts, cannot pull image, cannot see code     │
└─────────────────────────────────────────────────────────────────┘
```

## Security

| What | Where | Who Can See |
|------|-------|-------------|
| Prompts | Secrets Manager (your account) | Only Lambda role |
| KMS Key | KMS (your account) | Only Lambda role |
| Container | ECR (your account) | Only Lambda service (not admins) |
| Code | Inside container | Nobody (Lambda containers not inspectable) |

## Quick Start

### 1. Deploy Central Account

```bash
cd environments/central
mkdir -p prompts
echo "Your system prompt..." > prompts/system.txt
echo "Instructions..." > prompts/instruction.txt
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply
```

### 2. Build Container

```bash
cd container
docker build -t bedrock-protected-agent .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_URL>
docker tag bedrock-protected-agent:latest <ECR_URL>:v1
docker push <ECR_URL>:v1
```

### 3. Deploy Client Account

```bash
cd environments/client
cp terraform.tfvars.example terraform.tfvars
# Copy values from central terraform output
terraform init && terraform apply
```

### 4. Test

```bash
curl <API_GATEWAY_URL>/health
curl <API_GATEWAY_URL>/tools
curl -X POST <API_GATEWAY_URL>/invoke -H 'Content-Type: application/json' \
  -d '{"message": "Calculate 15 * 7", "session_id": "test"}'
```

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/tools` | GET | List agent tools |
| `/invoke` | POST | Invoke agent |

## Agent Tools

| Tool | Description |
|------|-------------|
| `calculator` | Math operations |
| `get_current_time` | Current date/time |
| `string_utils` | Text operations |
| `fibonacci` | Fibonacci numbers |

## Monitoring

```bash
# Bedrock invocations
aws cloudwatch get-metric-statistics --namespace AWS/Bedrock --metric-name Invocations \
  --dimensions Name=ModelId,Value=amazon.nova-lite-v1:0 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --period 300 --statistics Sum

# Lambda logs
aws logs tail /aws/lambda/bedrock-protected-agent --follow
```

## Update Prompts

```bash
cd environments/central/prompts && nano system.txt
cd .. && terraform apply
# Lambda will fetch new prompts on next cold start
```

## Update Container

```bash
cd container && docker build -t bedrock-protected-agent .
docker tag bedrock-protected-agent:latest <ECR_URL>:v2
docker push <ECR_URL>:v2
# Update container_image_tag = "v2" in client/terraform.tfvars
cd environments/client && terraform apply
```

## Cleanup

```bash
cd environments/client && terraform destroy
aws s3 rm s3://<AUDIT_BUCKET> --recursive
cd ../central && terraform destroy
```

## Structure

```
bedrock-protected-mode/
├── container/app/          # Strands agent (main.py, agent.py)
├── modules/
│   ├── central-account/    # ECR, Secrets, KMS, S3, SNS, Gatekeeper
│   └── client-account/     # Lambda, API Gateway, IAM, CloudTrail
└── environments/
    ├── central/            # Your account config
    └── client/             # Client account config
```

## Model

Uses **Amazon Nova Lite** (`amazon.nova-lite-v1:0`) - auto-enabled on first invoke.

## Cost Estimation (us-east-1)

### Fixed Monthly

| Service | Config | Cost/Month |
|---------|--------|------------|
| Lambda | Scales to 0 | ~$0 idle |
| API Gateway | HTTP API | ~$0 idle |
| Secrets Manager | 1 secret | ~$0.40 |
| KMS | 1 CMK | ~$1 |
| ECR | ~100MB image | ~$0.10 |
| CloudWatch Logs | 1GB/month | ~$0.50 |
| S3 (audit) | Minimal | ~$0.10 |
| **Subtotal Fixed** | | **~$2.50/month** |

### Variable (per usage)

| Service | Unit | Cost |
|---------|------|------|
| Lambda | per 1M requests | ~$0.20 |
| Lambda | per GB-second | ~$0.0000167 |
| API Gateway | per 1M requests | ~$1.00 |
| Nova Lite Input | 1M tokens | $0.06 |
| Nova Lite Output | 1M tokens | $0.24 |
| Data Transfer | per GB out | $0.09 |

### Example Scenarios

| Usage | Tokens/Month | Lambda | Total Est. |
|-------|--------------|--------|------------|
| Light (1K calls) | ~500K | ~$0.10 | ~$3 |
| Medium (10K calls) | ~5M | ~$1 | ~$5 |
| Heavy (100K calls) | ~50M | ~$10 | ~$25 |

*Costs are estimates for us-east-1. Actual costs may vary.*

## Why Lambda + Container?

| | Bedrock Agents | Lambda Container |
|--|---------------|------------------|
| Admin sees prompt | Yes | No |
| Admin can pull image | N/A | No (ECR in your account) |
| Admin can inspect code | N/A | No (containers not downloadable) |
| Scale to 0 | Yes | Yes |
| Cold start | None | 1-10s |
| Cost (idle) | $0 | ~$2.50/month |
| IP Protection | None | Cryptographic |

## Git

- Never commit prompts or terraform.tfvars
- Container has no embedded secrets (fetched at runtime)

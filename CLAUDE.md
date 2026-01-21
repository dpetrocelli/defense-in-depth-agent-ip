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
                              │ Only ECS task role can read
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  CLIENT ACCOUNT                                                 │
│  ✓ ECS Fargate + ALB                                           │
│  ✓ CloudTrail + EventBridge (tampering detection)              │
│  ✗ Cannot read prompts, cannot decrypt secrets                 │
└─────────────────────────────────────────────────────────────────┘
```

## Security

| What | Where | Who Can See |
|------|-------|-------------|
| Prompts | Secrets Manager (your account) | Only ECS task role |
| KMS Key | KMS (your account) | Only ECS task role |
| Container | ECR (your account) | Both (pull only) |

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
curl http://<ALB_URL>/health
curl http://<ALB_URL>/tools
curl -X POST http://<ALB_URL>/invoke -H 'Content-Type: application/json' \
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

# Container logs
aws logs tail /ecs/bedrock-protected-agent --follow
```

## Update Prompts

```bash
cd environments/central/prompts && nano system.txt
cd .. && terraform apply
aws ecs update-service --cluster bedrock-protected-agent --service bedrock-protected-agent --force-new-deployment
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
│   ├── central-account/    # ECR, Secrets, KMS, S3, SNS
│   └── client-account/     # ECS, ALB, IAM, CloudTrail
└── environments/
    ├── central/            # Your account config
    └── client/             # Client account config
```

## Model

Uses **Amazon Nova Lite** (`amazon.nova-lite-v1:0`) - auto-enabled on first invoke.

## Cost Estimation (us-east-1)

### Fixed Monthly (always running)

| Service | Config | Cost/Month |
|---------|--------|------------|
| ECS Fargate | 0.5 vCPU, 1GB RAM, 24/7 | ~$15 |
| ALB | 1 ALB + minimal LCUs | ~$18 |
| Secrets Manager | 1 secret | ~$0.40 |
| KMS | 1 CMK | ~$1 |
| ECR | ~100MB image | ~$0.10 |
| CloudWatch Logs | 1GB/month | ~$0.50 |
| S3 (audit) | Minimal | ~$0.10 |
| **Subtotal Fixed** | | **~$35/month** |

### Variable (per usage)

| Service | Unit | Cost |
|---------|------|------|
| Nova Lite Input | 1M tokens | $0.06 |
| Nova Lite Output | 1M tokens | $0.24 |
| ALB LCU | per LCU-hour | $0.008 |
| Data Transfer | per GB out | $0.09 |

### Example Scenarios

| Usage | Tokens/Month | Bedrock Cost | Total Est. |
|-------|--------------|--------------|------------|
| Light (1K calls) | ~500K | ~$0.15 | ~$35 |
| Medium (10K calls) | ~5M | ~$1.50 | ~$37 |
| Heavy (100K calls) | ~50M | ~$15 | ~$50 |

*Costs are estimates for us-east-1. Actual costs may vary.*

## Git

- Never commit prompts or terraform.tfvars
- Container has no embedded secrets

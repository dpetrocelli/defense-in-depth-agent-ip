# Cost Analysis

Cost breakdown for the defense-in-depth architecture at 50,000 requests/month in us-east-1, as reported in the paper.

## Fixed Monthly Costs

| Service | Component | Cost/Month |
|---------|-----------|------------|
| Secrets Manager | 1 secret (system prompt) | $0.40 |
| KMS | 1 customer-managed key | $1.00 |
| CloudWatch | Logs + metrics + dashboard | $0.50 |
| EventBridge | Cross-account event bus | $0.00 (free tier) |
| Lambda | Idle (scales to zero) | $0.00 (free tier) |
| **Subtotal** | | **$1.90/month** |

## Variable Costs (at 50K requests/month)

| Service | Usage | Unit Cost | Monthly |
|---------|-------|-----------|---------|
| Lambda (gatekeeper) | 50K invocations, 256MB, ~100ms avg | $0.0000167/GB-s | ~$0.02 |
| Lambda (agent) | 50K invocations, 512MB, ~2s avg | $0.0000167/GB-s | ~$0.85 |
| API Gateway | 50K HTTP API requests | $1.00/1M | ~$0.05 |
| Bedrock (Nova Lite) | ~25M input tokens | $0.06/1M | ~$1.50 |
| Bedrock (Nova Lite) | ~10M output tokens | $0.24/1M | ~$2.40 |
| EventBridge | ~50K events | $1.00/1M | ~$0.05 |
| **Subtotal** | | | **~$4.87/month** |

## Total at 50K Requests/Month

| Component | Cost |
|-----------|------|
| Fixed infrastructure | $1.90 |
| Variable (compute + inference) | $4.87 |
| **Total** | **~$6.77/month** |

The paper reports **$1.90/month** as the infrastructure-only cost (excluding Bedrock inference), which is the cost of the defense layers themselves. Inference costs are application-dependent and would exist regardless of the security architecture.

## Comparison with TEE-Based Approaches

| Approach | Monthly Cost | Notes |
|----------|-------------|-------|
| **This architecture** | $1.90 (infra) | Standard serverless, scales to zero |
| Confidential VM (c6i.metal) | ~$3,528 | $4.90/hr, must run continuously |
| Confidential VM (c6a.2xlarge) | ~$252 | $0.35/hr, AMD SEV, still always-on |

The serverless approach is **130-1,800x cheaper** than TEE-based alternatives for the security infrastructure alone.

## Cost Scaling

| Requests/Month | Infra | Compute | Inference | Total |
|----------------|-------|---------|-----------|-------|
| 1,000 | $1.90 | ~$0.02 | ~$0.10 | ~$2.02 |
| 10,000 | $1.90 | ~$0.20 | ~$1.00 | ~$3.10 |
| 50,000 | $1.90 | ~$0.92 | ~$3.95 | ~$6.77 |
| 100,000 | $1.90 | ~$1.84 | ~$7.90 | ~$11.64 |
| 500,000 | $1.90 | ~$9.20 | ~$39.50 | ~$50.60 |

Infrastructure cost remains constant at $1.90/month regardless of scale. Variable costs grow linearly.

## Provisioned Concurrency (Optional)

For latency-sensitive deployments that need to eliminate cold starts (1-2s):

| Config | Cost/Month |
|--------|------------|
| 1 provisioned instance | ~$4.50 |
| 3 provisioned instances | ~$13.50 |

This is still orders of magnitude cheaper than always-on TEE instances.

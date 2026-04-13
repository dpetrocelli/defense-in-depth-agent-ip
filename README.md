# Defense-in-Depth Agent IP

Deploy AI agents in customer cloud accounts while keeping system prompts (intellectual property) completely protected via a four-layer defense-in-depth architecture.

## Architecture

![Architecture](docs/generated-diagrams/bedrock_protected_architecture.png)

The architecture composes four defense layers into a trust chain across two AWS accounts:

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| L1 | HMAC-SHA256 signed prompt delivery | Confidentiality + integrity |
| L2 | OWASP-aligned input validation with risk scoring | Injection defense |
| L3 | Output filtering + ZWC steganographic watermarking | Leakage detection + forensic attribution |
| L4 | Cross-account EventBridge monitoring | Real-time alerting + audit |

See [CLAUDE.md](CLAUDE.md) for full setup instructions, API reference, security configuration, and cost estimation.

## Quick Start

```bash
# 1. Deploy central account (prompts, gatekeeper, monitoring)
cd environments/central && terraform init && terraform apply

# 2. Build container with BuildKit secret mount
cd container
DOCKER_BUILDKIT=1 docker buildx build \
  --secret id=signing_key,src=/tmp/.signing_key \
  -t bedrock-protected-agent .

# 3. Deploy client account (agent, API gateway, event forwarding)
cd environments/client && terraform init && terraform apply

# 4. Run penetration tests (63 tests, 12 categories)
python3 tools/pentest_runner.py
```

## Validation

- **63 penetration tests** across 12 attack categories: 100% pass rate
- **P99 latency overhead**: 68.3 ms (imperceptible in conversational AI)
- **Infrastructure cost**: ~$1.90/month at 50K requests/month

See [docs/COST_ANALYSIS.md](docs/COST_ANALYSIS.md) for detailed cost breakdown.

## Security Fixes (v2)

- Dockerfile uses BuildKit `--mount=type=secret` instead of ARG (key never in any layer)
- Direct Secrets Manager fallback blocked in production (`ENVIRONMENT=production`)
- Pre-flight Bedrock logging check is fail-closed (refuses to start if cannot verify)
- ZWC watermark distributed across random word boundaries (resists naive stripping)
- Error messages sanitized (no vendor infrastructure details leaked)

## License

See [LICENSE](LICENSE).

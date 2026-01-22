# Secure Prompt Delivery Architecture

## The Problem

When deploying AI agents in customer accounts, we need to protect our intellectual property (prompts) while allowing customers to use the agent. Even if a customer has admin access to their AWS account, they should not be able to extract the prompts.

## The Solution: Embedded Signing Key + Lambda Gatekeeper

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  CENTRAL ACCOUNT (Our Control)                                       │    │
│  │                                                                      │    │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐       │    │
│  │  │ ECR Registry │    │   Lambda     │    │ Secrets Manager  │       │    │
│  │  │ (our image)  │    │  Gatekeeper  │───►│ (prompts)        │       │    │
│  │  └──────────────┘    └──────▲───────┘    └──────────────────┘       │    │
│  │                             │                                        │    │
│  │                    API Gateway (HTTPS)                               │    │
│  │                             │                                        │    │
│  └─────────────────────────────│────────────────────────────────────────┘    │
│                                │                                             │
│  ┌─────────────────────────────│────────────────────────────────────────┐    │
│  │  CLIENT ACCOUNT             │                                        │    │
│  │                             │                                        │    │
│  │  ┌──────────────────────────┴─────────────────────────────────┐     │    │
│  │  │  ECS Fargate Container (our image)                          │     │    │
│  │  │                                                             │     │    │
│  │  │  ┌─────────────────────────────────────────────────────┐   │     │    │
│  │  │  │  /app/.signing_key  (embedded at build time)        │   │     │    │
│  │  │  │  - Used to sign requests to gatekeeper              │   │     │    │
│  │  │  │  - Cannot be extracted (no ECS Exec, no docker pull)│   │     │    │
│  │  │  └─────────────────────────────────────────────────────┘   │     │    │
│  │  │                                                             │     │    │
│  │  │  Agent Code:                                                │     │    │
│  │  │  1. Read signing key from embedded file                    │     │    │
│  │  │  2. Sign request (HMAC-SHA256)                             │     │    │
│  │  │  3. Call gatekeeper with signature                         │     │    │
│  │  │  4. Receive prompts (only in memory)                       │     │    │
│  │  │  5. Filter responses for prompt leakage                    │     │    │
│  │  └─────────────────────────────────────────────────────────────┘     │    │
│  │                                                                      │    │
│  │  Client Admin CANNOT:                                                │    │
│  │  ✗ Modify the container image (ECR in central account)             │    │
│  │  ✗ Pull the image to inspect (no ECR permissions)                  │    │
│  │  ✗ ECS Exec into container (disabled + alerted)                    │    │
│  │  ✗ Create malicious container with valid signature (no key)        │    │
│  │                                                                      │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Request Flow

```
Container                    API Gateway              Lambda Gatekeeper
    │                            │                          │
    │  1. Generate signature     │                          │
    │     HMAC(key, timestamp:   │                          │
    │          nonce:account)    │                          │
    │                            │                          │
    │  2. POST /get-prompts      │                          │
    │     X-Signature: abc123    │                          │
    │     X-Timestamp: 170000000 │                          │
    │     X-Nonce: randomhex     │                          │
    │     X-Client-Account: 123  │                          │
    ├───────────────────────────►├─────────────────────────►│
    │                            │                          │
    │                            │  3. Validate:            │
    │                            │     - Account allowed?   │
    │                            │     - Timestamp fresh?   │
    │                            │     - Signature valid?   │
    │                            │                          │
    │                            │  4. If valid, fetch      │
    │                            │     prompts from         │
    │                            │     Secrets Manager      │
    │                            │                          │
    │  5. Receive prompts        │                          │
    │◄──────────────────────────────────────────────────────┤
    │                            │                          │
    │  6. Apply defensive        │                          │
    │     prompt additions       │                          │
    │                            │                          │
    │  7. Process user request   │                          │
    │                            │                          │
    │  8. Filter response for    │                          │
    │     prompt leakage         │                          │
```

## Attack Scenarios

| Attack | Why It Fails |
|--------|--------------|
| Create malicious task definition with our image | Runs OUR code, not theirs |
| Create malicious task definition with own image | No signing key → gatekeeper rejects |
| Copy signing key to own image | Can't read our image (no ECR access) |
| ECS Exec to extract key | Disabled + generates alert |
| Modify our image | Can't push to our ECR |
| Intercept network traffic | TLS encrypted, key never transmitted |
| Prompt injection | Defensive prompts + response filtering |
| Replay attack | Timestamp + nonce validation |

## Multi-Layer Defense

### Layer 1: Infrastructure (Prevention)
- Signing key embedded in container image
- ECS Exec disabled
- ECR in central account
- Trust policy conditions on task role

### Layer 2: Application (Prevention)
- HMAC signature validation
- Timestamp freshness check
- Client account allowlist
- Response filtering for prompt leakage

### Layer 3: Monitoring (Detection)
- CloudTrail audit logs
- EventBridge alerts
- Failed signature attempt monitoring
- SNS notifications

### Layer 4: AI (Mitigation)
- Defensive prompt additions
- Input sanitization
- Output filtering

## Build Process

```bash
# 1. Deploy central account (creates gatekeeper + generates signing key)
cd environments/central
terraform apply

# 2. Get the signing key (SENSITIVE!)
SIGNING_KEY=$(terraform output -raw gatekeeper_signing_key)

# 3. Build container with embedded key
cd ../../container
./build.sh "$SIGNING_KEY" "190045319446.dkr.ecr.us-east-1.amazonaws.com/bedrock-protected-agent" "v1"

# 4. Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 190045319446.dkr.ecr.us-east-1.amazonaws.com
docker push 190045319446.dkr.ecr.us-east-1.amazonaws.com/bedrock-protected-agent:v1

# 5. Deploy client account
cd ../environments/client
# Update terraform.tfvars with gatekeeper_url from central outputs
terraform apply
```

## Security Guarantee

With this architecture, **it is cryptographically impossible** for a client admin to extract the prompts because:

1. Only code with the signing key can authenticate with the gatekeeper
2. The signing key is embedded in our container image
3. The client cannot modify our image or extract the key
4. Any attempt to access the key is detected and alerted

The only remaining vector is **prompt injection**, which is mitigated (but not 100% eliminated) through:
- Defensive system prompt additions
- Input sanitization
- Response filtering

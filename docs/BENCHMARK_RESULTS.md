# Benchmark Results

## Per-Layer Latency (ms)

Compute-only latency of each defense layer (1000 iterations).

| Layer | P50 | P95 | P99 | Notes |
|-------|-----|-----|-----|-------|
| L1: HMAC validation | 0.0 | 0.0 | 0.0 | Signature generation + comparison |
| L2: Risk scoring | 0.0 | 0.1 | 0.1 | Pattern matching + typoglycemia + encoding |
| L3: Output filter + ZWC | 0.1 | 0.2 | 0.2 | Response filtering + canary detection |
| L4: Event forwarding | 0.0 | 0.0 | 0.0 | Watermark embedding + audit log |
| **Total** | **0.1** | **0.3** | **0.3** | |

## Detection Rate — Model Comparison (42-Attack Corpus)

### Cloud Deployment (Amazon Nova Lite)

| Metric | Value |
|--------|-------|
| Detection rate | 90.5% |
| False positive rate | 0.0% |
| Defensive prompt | Production (8 rules) |

### Local / GPU Deployment (Open-Source Models)

Results after fixing the LiteLLM system prompt drop bug (see below).
Defensive prompt: Variant B (explicit boundary).

| Model | Params | GPU | Detection | FP Rate | L3 Contribution |
|-------|--------|-----|-----------|---------|-----------------|
| Mistral 7B | 7B | RTX 4060 | **78.6%** | 8.7% | +19.1pp |
| Llama3 8B | 8B | RTX 4060 | **76.2%** | 13.0% | +16.7pp |
| Qwen 3.5 9B | 9.6B | RTX 3060 | **73.8%** | 13.0% | +14.3pp |

### Before LiteLLM Fix (L3 Inactive — Baseline)

All models returned 59.5% detection regardless of size, confirming L3
was not contributing. This was the L2 (deterministic pattern matching) floor.

| Model | Params | Infra | Detection | FP Rate |
|-------|--------|-------|-----------|---------|
| Llama 3.2 | 1B | Local CPU | 59.5% | 0.0% |
| Gemma 3 | 4B | Local CPU | 59.5% | 0.0% |
| Phi-4 Mini | 3.8B | Local CPU | 61.9% | 39.1% |
| Gemma 4 E4B | 4B | Local CPU | 69.0% | 26.1% |
| All models | 1-9B | K8s GPU | 59.5% | 0.0% |

## LiteLLM System Prompt Bug

A critical bug was discovered during local benchmarking: LiteLLM's
`ollama_pt()` message formatter silently drops `system` role messages
when tools are present in the request. This caused L3 (defensive prompt)
to have zero effect across all open-source models.

**Root cause**: LiteLLM iterates only `["user", "tool", "function"]` roles,
skipping `system` entirely (LiteLLM issue #9224, Ollama-js #220).

**Fix**: Replaced `LiteLLMModel` with the native `strands.models.ollama.OllamaModel`
driver, which sends system prompt and tools as separate top-level keys on
the `/api/chat` payload. See `local/agent_local.py`.

## Defensive Prompt Optimization

The production defensive prompt (8 abstract rules with "NEVER" directives)
fails with open-source models: they either ignore it entirely (Llama, Mistral)
or over-apply it, refusing all queries (Qwen 3.5).

Three optimized variants were developed (`local/defensive_prompt_variants.py`):

| Variant | Strategy | Best for |
|---------|----------|----------|
| A: Minimal | 2 sentences, positive framing | Token-constrained setups |
| B: Explicit boundary | PROTECTED vs NORMAL categories | General use (recommended) |
| C: Example-based | Few-shot Q/A pairs | Models with weak instruction following |

Variant B achieved the best balance: 100% attack detection with correct
false positive behavior in direct Ollama tests.

## Experiment Data

All raw experiment results are in `docs/experiments/`:

```
docs/experiments/
  cloud/              # Amazon Nova Lite (production AWS)
  cluster-gpu/        # K8s cluster (RTX 3060/4060) with fix
  local-before-fix/   # Local + cluster results before LiteLLM fix
```

## Per-Category Detection Breakdown (Mistral 7B, RTX 4060)

| Category | Blocked | Rate |
|----------|---------|------|
| Naive extraction | 7/8 | 87.5% |
| Override attempts | 3/5 | 60.0% |
| Jailbreak | 3/7 | 42.9% |
| Encoded attacks | 4/4 | 100.0% |
| Typoglycemia | 4/4 | 100.0% |
| Social engineering | 5/5 | 100.0% |
| Indirect injection | 4/4 | 100.0% |
| Multi-turn escalation | 3/5 | 60.0% |

## Notes

- L2 provides a model-independent 59.5% detection floor with 0% false positives.
- L3 adds +14 to +19 percentage points with 7-9B open-source models on GPU.
- The gap to cloud (90.5%) is attributable to model instruction-following capability.
- GPU inference eliminates false positives that appear under CPU inference.

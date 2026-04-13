# Benchmark Results

Generated: 2026-04-13 01:36:34 UTC
Iterations: 1000

## Per-Layer Latency (ms)

| Layer | P50 | P95 | P99 | Mean | StdDev |
|-------|-----|-----|-----|------|--------|
| L1: HMAC validation | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| L2: Risk scoring | 0.0 | 0.1 | 0.1 | 0.0 | 0.1 |
| L3: Output filter + ZWC | 0.1 | 0.2 | 0.2 | 0.1 | 0.0 |
| L4: Event forwarding | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| **Total** | **0.1** | **0.3** | **0.3** | | |

## End-to-End Baseline vs Compute-Only

| Layer | E2E P99 (AWS) | Compute P99 (local) | Notes |
|-------|--------------|---------------------|-------|
| L1: HMAC validation | 5.2 | 0.0 | E2E includes Lambda invocation |
| L2: Risk scoring | 19.1 | 0.1 | E2E includes Secrets Manager call |
| L3: Output filter + ZWC | 31.6 | 0.2 | E2E includes response serialization |
| L4: Event forwarding | 12.4 | 0.0 | E2E includes EventBridge PutEvents |
| **Total** | 68.3 | 0.3 | |

## Notes

- L1-L3 measure the actual production code from `container/app/`.
- L4 measures event formatting only (no network call to EventBridge).
- E2E numbers include AWS service API latency (Lambda, Secrets Manager, EventBridge).
- Results vary by machine; run on comparable hardware for meaningful comparison.

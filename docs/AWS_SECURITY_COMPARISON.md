# AWS & OWASP Security Best Practices Comparison

Comparison of our implementation vs. official AWS and OWASP recommendations.

## Sources

- [AWS Bedrock Prompt Injection Security](https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-injection.html)
- [AWS Bedrock Guardrails - Prompt Attack Detection](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails-prompt-attack.html)
- [AWS Preventative Security Best Practices for Agents](https://docs.aws.amazon.com/bedrock/latest/userguide/security-best-practice-agents.html)
- [OWASP LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OWASP Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)
- [AWS Certified Generative AI Developer - Professional](https://aws.amazon.com/certification/certified-generative-ai-developer-professional/)

---

## Comparison Matrix

| Best Practice | AWS Recommendation | OWASP Recommendation | Our Implementation | Status |
|---------------|-------------------|---------------------|-------------------|--------|
| **Input Validation** | Validate and sanitize all user input | Pattern matching, encoding detection, length limits | `sanitize_user_input()` in response_filter.py | ✅ |
| **Input Tagging** | Use `<amazon-bedrock-guardrails-guardContent>` tags | Separate/denote untrusted content | `<user_input>` tags in templates | ✅ |
| **Guardrails** | Use Bedrock Guardrails with HIGH strength | Semantic filters, content policies | WAF rules + response_filter.py | ⚠️ Partial |
| **Prompt Leakage Detection** | Enable Standard tier guardrails | Monitor for system prompt in output | Canary tokens + leak patterns | ✅ |
| **Least Privilege** | Minimal IAM permissions | Grant minimal necessary permissions | Permission boundaries in IAM | ✅ |
| **Encryption** | Use CMK for agent resources | - | KMS encryption for secrets | ✅ |
| **Secure Connections** | Always use HTTPS | - | HTTPS via API Gateway/ALB | ✅ |
| **PII Protection** | Don't include PII in unencrypted fields | Detect PII in outputs | Not implemented | ❌ Gap |
| **Human-in-Loop** | Enable user confirmation for sensitive actions | Human-in-loop for privileged ops | Not implemented (stateless) | ⚠️ N/A |
| **Monitoring** | Implement robust monitoring | Log all interactions, rate limit | CloudWatch alarms + audit logs | ✅ |
| **Pre-processing** | Enable default pre-processing prompt | - | Pre-flight compliance check | ✅ |
| **System Prompt Separation** | Use system prompts (not user prompts) | Clear data boundaries | Defensive prompt structure | ✅ |
| **Encoding Detection** | - | Detect Base64, hex, Unicode | Patterns in sanitize_user_input | ⚠️ Basic |
| **Output Validation** | - | Sanitize before rendering | filter_response() | ✅ |
| **Typoglycemia Defense** | - | Recognize misspelled variants | Not implemented | ❌ Gap |
| **RAG Triad Evaluation** | - | Assess context relevance, groundedness | Not implemented | ❌ Gap |

---

## AWS-Specific Recommendations

### 1. Bedrock Guardrails Configuration

**AWS Recommends:** Use Bedrock Guardrails with prompt attack filter set to HIGH.

```json
{
  "contentPolicyConfig": {
    "filtersConfig": [{
      "type": "PROMPT_ATTACK",
      "inputStrength": "HIGH",
      "inputAction": "BLOCK"
    }],
    "tierConfig": {
      "tierName": "STANDARD"
    }
  }
}
```

**Our Gap:** We don't use native Bedrock Guardrails because:
- Our agent runs in the client account
- We can't control client's Bedrock configuration
- We implement equivalent protection at the application layer

**Recommendation:** Add documentation for clients who want to enable Bedrock Guardrails additionally.

### 2. Input Tagging (Critical)

**AWS Recommends:** Tag user input with `<amazon-bedrock-guardrails-guardContent_xyz>`:

```
System instructions here...

<amazon-bedrock-guardrails-guardContent_xyz>
{user_input}
</amazon-bedrock-guardrails-guardContent_xyz>
```

**Our Implementation:** We use `<user_input>` tags in templates.

**Action:** Update templates to use AWS-recommended tags for Bedrock compatibility.

### 3. Standard Tier for Prompt Leakage

**AWS Recommends:** Use STANDARD tier for prompt leakage detection (2025 feature).

**Our Implementation:** We detect prompt leakage via:
- Canary tokens
- Pattern matching in response_filter.py
- Chunk comparison with system prompt

**Status:** Equivalent protection without Bedrock dependency.

---

## OWASP LLM Top 10 2025 Coverage

| Risk | Description | Our Mitigation |
|------|-------------|----------------|
| **LLM01: Prompt Injection** | Crafted inputs override instructions | Input sanitization, defensive prompts, response filtering |
| **LLM02: Insecure Output** | Unvalidated model output | `filter_response()`, watermarking |
| **LLM03: Training Data Poisoning** | Corrupted training data | N/A (using AWS models) |
| **LLM04: Model DoS** | Resource exhaustion | Rate limiting, request size limits |
| **LLM05: Supply Chain** | Compromised dependencies | Multi-stage Docker, minimal dependencies |
| **LLM06: Sensitive Info Disclosure** | Leaking secrets in output | Canary tokens, leak detection |
| **LLM07: Insecure Plugin Design** | Vulnerable tools | Tool input validation |
| **LLM08: Excessive Agency** | Too many permissions | Least privilege IAM, limited tools |
| **LLM09: Overreliance** | Trusting AI blindly | N/A (user education) |
| **LLM10: Model Theft** | Extracting model weights | N/A (using AWS models) |

---

## Gaps to Address

### High Priority

1. **PII Detection**
   - AWS recommends using Amazon Comprehend/Macie
   - Add PII detection to response_filter.py

2. **Typoglycemia Defense**
   - OWASP recommends detecting misspelled variants
   - Add fuzzy matching for injection patterns

3. **Encoding Detection Enhancement**
   - Currently basic pattern matching
   - Add Base64, hex, ROT13 decoding attempts detection

### Medium Priority

4. **Bedrock Guardrails Documentation**
   - Document how clients can additionally enable Bedrock Guardrails
   - Provide Terraform module for guardrail configuration

5. **RAG Security**
   - If RAG is added, implement context relevance scoring
   - Tag RAG outputs as untrusted

### Low Priority

6. **Human-in-Loop**
   - Document how to add approval workflows for sensitive operations
   - Not critical for stateless API use case

---

## AWS Certification Alignment

Based on [AWS Certified Generative AI Developer - Professional](https://aws.amazon.com/certification/certified-generative-ai-developer-professional/) exam guide:

### Domain 3: AI Safety, Security, and Governance (20%)

| Skill | Our Coverage |
|-------|--------------|
| Develop protected AI environments (VPC endpoints, IAM) | ✅ VPC isolation, IAM policies |
| Privacy-preserving systems (PII detection, guardrails) | ⚠️ Partial - no PII detection |
| Bedrock native data privacy features | ⚠️ Not using native features |
| Guardrails to filter outputs | ✅ Application-level filtering |

### Recommended Study Topics

Based on the exam domains, ensure understanding of:

1. **Amazon Bedrock Guardrails** - Content filters, prompt attack detection
2. **Amazon Comprehend** - PII detection capabilities
3. **Amazon Macie** - Sensitive data discovery
4. **IAM policies for Bedrock** - Least privilege patterns
5. **VPC endpoints** - Network isolation for Bedrock
6. **CloudWatch/CloudTrail** - Monitoring and auditing

---

## Implementation Roadmap

### Phase 1: Quick Wins (1-2 days)

- [ ] Add PII detection patterns to response_filter.py
- [ ] Enhance encoding detection (Base64, hex)
- [ ] Update templates to use AWS-recommended input tags
- [ ] Add typoglycemia patterns for common injection phrases

### Phase 2: Documentation (1 day)

- [ ] Add Bedrock Guardrails setup guide for clients
- [ ] Document RAG security considerations
- [ ] Add AWS certification study notes

### Phase 3: Optional Enhancements (future)

- [ ] Integrate Amazon Comprehend for PII detection
- [ ] Add support for Bedrock Guardrails API
- [ ] Implement RAG Triad evaluation if RAG is added

---

## References

### AWS Documentation
- [Amazon Bedrock Security](https://docs.aws.amazon.com/bedrock/latest/userguide/security.html)
- [Prompt Engineering Guidelines](https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-engineering-guidelines.html)
- [Guardrails Components](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails-components.html)

### OWASP Resources
- [OWASP Top 10 for LLMs 2025 PDF](https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf)
- [Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)

### AWS Training
- [AWS Generative AI for Developers Certificate](https://www.coursera.org/professional-certificates/aws-generative-ai-developers)
- [Exam Guide PDF](https://d1.awsstatic.com/onedam/marketing-channels/website/aws/en_US/certification/approved/pdfs/docs-aip/AWS-Certified-Generative-AI-Developer-Pro_Exam-Guide.pdf)

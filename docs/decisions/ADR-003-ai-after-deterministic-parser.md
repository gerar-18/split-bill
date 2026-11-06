# ADR-003 — Introduce LLM parsing after deterministic parsing

Status: Accepted

## Decision

Build on-device OCR and deterministic parsing in Wave 1 (`M5`–`M6`) before introducing an LLM in Wave 2 (`M7`–`M7.5`). When introduced, LLM extraction must be hosted behind the backend proxy service, unlocked via StoreKit 2, require explicit user consent, and produce structured data that is schema-validated and domain-validated before user confirmation.

## Rationale

1. **Measurable Baseline**: Deterministic regex and geometry parsing operates in <1 ms, costs $0, works offline, and guarantees reproducible results. It acts as an objective benchmark.
2. **Security & Secrets Hygiene**: Embedding LLM API keys directly in the iOS client binary is a severe security vulnerability. Placing LLM calls behind a NestJS backend proxy (`M7`) protects credentials and enables server-side rate limiting.
3. **App Store Compliance**:
   - **Guideline 5.1.2(i)**: Explicit user consent is legally required before transmitting receipt images or OCR text to a third-party AI provider.
   - **Guideline 3.1.1**: Unlocking cloud AI parsing capabilities inside the app requires native In-App Purchases via `StoreKit 2`.
4. **Domain Integrity**: All LLM outputs must be validated against `ReceiptParser` domain invariants before presenting them to the user in `ParsedReceiptReviewDraft` for human confirmation.

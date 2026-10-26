# ADR-003 — Introduce LLM parsing after deterministic parsing

Status: Accepted

## Decision

Build OCR and deterministic parsing before introducing an LLM.

## Rationale

This establishes a measurable baseline and prevents the project from hiding parsing problems behind an opaque model call. LLM extraction will produce structured data that is schema-validated and domain-validated before user confirmation.

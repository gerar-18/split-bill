# ADR-001 — Local-first initial architecture

Status: Accepted

## Context

The project is primarily an iOS learning project. Introducing authentication, networking, a database, and cloud infrastructure before the core workflow is stable would obscure the mobile and domain-learning goals.

## Decision

The MVP will run locally using SwiftUI, a domain layer, and SwiftData. Backend infrastructure is introduced only when a product requirement needs synchronization or collaboration.

## Consequences

Positive:
- faster feedback;
- lower infrastructure complexity;
- easier testing;
- better focus on iOS fundamentals.

Trade-off:
- collaboration cannot exist in the initial version.

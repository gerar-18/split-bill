# ADR-002 — Keep domain logic independent from UI

Status: Accepted

## Decision

Receipt, money, assignment, splitting, and validation rules live outside SwiftUI views.

## Rationale

The same rules will later be used by UI, persistence, tests, and potentially backend services. Keeping them independent also makes agent-generated changes easier to verify.

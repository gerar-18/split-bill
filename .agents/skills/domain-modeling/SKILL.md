---
name: domain-modeling
description: >-
  Use this skill when designing or modifying domain entities, value objects, invariants,
  or business rules in apps/SplitBill/SplitBill/Domain/ (such as Receipt, ReceiptItem,
  Participant, Assignment, or SplitEngine).
---

# Domain Modeling — SplitBill

## When to Use
- **Agent**: Activate before creating or editing any file under `apps/SplitBill/SplitBill/Domain/` or when planning M1+ domain models.
- **Developer**: Use when modeling business rules for receipts, participants, item assignments, and split modes.

## Core Principles

1. **Zero UI or Persistence Coupling (ADR-002)**:
   - Files in `apps/SplitBill/SplitBill/Domain/` may only `import Foundation`.
   - Never `import SwiftUI` or couple domain types to SwiftData `@Model` classes.
2. **Value Semantics (`struct` and `enum`)**:
   - Model domain concepts as immutable or value-semantic `struct` and `enum` types conforming to `Sendable`, `Equatable`, and `Identifiable` where appropriate.
3. **Make Illegal States Unrepresentable**:
   - Prefer strongly-typed domain structures over raw primitives (`String`, `Int`, `Double`).
   - Validate invariants at construction time or through explicit domain operations that return typed errors.

## Canonical Domain Patterns (Swift 6)

```swift
import Foundation

/// Strongly-typed identifier or value object
struct Participant: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String

    init(id: UUID = UUID(), name: String) throws(DomainError) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw .emptyParticipantName
        }
        self.id = id
        self.name = trimmed
    }
}

/// Exhaustive sum type for split modes (docs/domain/money-and-splitting.md)
enum SplitMode: Equatable, Sendable {
    case wholeItem(Participant.ID)
    case equal(Set<Participant.ID>)
    case percentage([Participant.ID: Int]) // Basis points or whole percentages summing to 100
    case portion([Participant.ID: Int])    // Shares/portions > 0
}

enum DomainError: Error, Equatable, Sendable {
    case emptyParticipantName
    case noParticipantsAssigned
    case invalidPercentageTotal(Int)
    case negativeAmount
}
```

## Verification Step
After adding or modifying domain models:
1. Confirm no file in `Domain/` imports `SwiftUI`.
2. Add unit tests in `apps/SplitBill/SplitBillTests/` covering both valid creation and invalid states (`#expect(throws:)`).
3. Run `./scripts/verify.sh`.

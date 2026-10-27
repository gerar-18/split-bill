---
name: money-calculation
description: >-
  Use this skill whenever designing, implementing, or testing monetary types (Money,
  Currency), tax/tip calculation, rounding policies, or split allocation algorithms
  in SplitBill.
---

# Money Calculation & Allocation — SplitBill

## When to Use
- **Agent**: Activate whenever working on `Money`, currency representation, tax/tip distribution, rounding, or splitting math in `Domain/` and `SplitBillTests/`.
- **Developer**: Use when defining financial rules in M1 or auditing calculation bugs.

## 1. Authoritative Representation Rule
- **NEVER use `Float` or `Double`** to store or calculate money (`0.1 + 0.2 != 0.3` in IEEE 754 binary floating point).
- Represent monetary amounts as **integer minor units (`Int64` cents)** paired with an explicit `Currency` code (ISO 4217, e.g., `MXN`, `USD`), or use `Decimal` strictly for intermediate percentage/tax multiplication before rounding back to integer minor units.

```swift
import Foundation

struct Currency: Equatable, Hashable, Sendable {
    let code: String
    let minorUnitScale: Int // e.g., 2 for MXN/USD (100 cents = $1.00)

    static let usd = Currency(code: "USD", minorUnitScale: 2)
    static let mxn = Currency(code: "MXN", minorUnitScale: 2)
}

struct Money: Equatable, Comparable, Hashable, Sendable {
    let amountInMinorUnits: Int64
    let currency: Currency

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare different currencies")
        return lhs.amountInMinorUnits < rhs.amountInMinorUnits
    }
}
```

## 2. The Core Allocation Invariant
For every valid completed receipt:
$$\sum_{p \in \text{Participants}} \text{allocated}(p) == \text{receipt.total}$$

Not a single cent may be lost or invented during division.

## 3. Deterministic Remainder Allocation (Largest Remainder / Hamilton's Method)
When splitting an amount $A$ (in minor units) across $N$ participants:
1. Compute integer quotient $q = A \div N$ and remainder $r = A \bmod N$.
2. Every participant receives at least $q$ minor units.
3. The remaining $r$ cents ($0 \le r < N$) are distributed **1 cent each** to the first $r$ participants in a **deterministic order** (e.g., sorted by highest fractional remainder first, with participant order or ID as a deterministic tie-breaker).

### Canonical Truth Table (Must Pass in Unit Tests)

| Total Amount | Split Mode / Shares | Expected Allocation | Sum Check |
|---|---|---|---|
| `$10.00` (`1000` cents) | Equal across 3 (`[A, B, C]`) | `A: 334`, `B: 333`, `C: 333` | `1000` (`$10.00`) |
| `$0.01` (`1` cent) | Equal across 2 (`[A, B]`) | `A: 1`, `B: 0` | `1` (`$0.01`) |
| `$0.00` (`0` cents) | Equal across 3 (`[A, B, C]`) | `A: 0`, `B: 0`, `C: 0` | `0` (`$0.00`) |
| `$10.00` (`1000` cents) | Percentage `33%, 33%, 34%` | `A: 330`, `B: 330`, `C: 340` | `1000` (`$10.00`) |

## Verification Step
Run `./scripts/verify.sh` and ensure parameterized tests in `SplitBillTests` verify all rows of the canonical truth table above.

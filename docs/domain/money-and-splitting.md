# Money and Splitting Rules — Specification

## 1. Representation of Money

Monetary amounts are stored as exact integer minor units (`amountInMinorUnits: Int64`, e.g., cents or centavos) paired with an explicit ISO 4217 `Currency` (such as `MXN` or `USD` with `minorUnitScale = 2`).

Binary floating-point types (`Float`, `Double`) are strictly forbidden in domain models and calculations.

## 2. Supported Split Modes

SplitBill supports 4 exhaustive modes for each line item:
1. **`wholeItem(Participant.ID)`**: 100% of the item cost is allocated to a single participant.
2. **`equal(Set<Participant.ID>)`**: Cost is split equally among the assigned participants.
3. **`percentage([Participant.ID: Int])`**: Cost is allocated by whole integer percentages that must sum to exactly `100%` (each share $> 0$).
4. **`portion([Participant.ID: Int])`**: Cost is allocated proportionally by integer portions/shares (each portion $> 0$, e.g., `A: 1, B: 2`).

## 3. Allocation Policy: Hamilton's Method (Largest Remainder Method)

To satisfy the invariant that **no cent is lost or created**, amounts with fractional division are allocated deterministically via Hamilton's Method:

1. For an amount $A$ and participant weights $w_i$ with total weight $W = \sum w_i$:
2. Every participant receives an integer floor quota:
   $$q_i = \lfloor (A \times w_i) / W \rfloor$$
3. The exact remainder numerator is:
   $$r_i = (A \times w_i) \bmod W$$
4. The remaining $R = A - \sum q_i$ cents ($0 \le R < N$) are awarded $+1$ minor unit each to the participants ranked by:
   - **Primary**: Largest remainder numerator $r_i$ descending.
   - **Tie-breaker**: Canonical participant order in `Receipt.participants` ascending.

## 4. Tax & Tip Allocation Policy

- Receipt-level `tax` and `tip` are allocated across participants **proportionally to each participant's pre-tax line item subtotal** using Hamilton's Method.
- Participants with an item subtotal of `$0.00` (e.g., attending without consuming) are allocated `$0.00` tax and tip.
- If the receipt has no items or the item subtotal is `$0.00`, any flat tax or tip is split equally among all receipt participants.

## 5. Master Allocation Invariant

For every valid completed receipt:
$$\sum_{p \in \text{Participants}} \text{personTotal}(p) == \text{receipt.total}$$
where $\text{receipt.total} = \text{itemsSubtotal} + \text{tax} + \text{tip}$.

---
name: money-calculation
description: Design and test monetary calculations, allocation, rounding, tax, and tip for SplitBill.
---

# Money Calculation

Never use binary floating point as the authoritative representation of money. Define currency and scale explicitly. Document rounding. Test odd-cent allocation and reconciliation. The sum of participant amounts must reconcile to the receipt total according to the chosen policy.

---
name: swift-guidelines
description: Guidance for modern Swift implementation in SplitBill, especially value semantics, optionals, concurrency, errors, and testability.
---

# Swift Guidelines

Prefer value types for domain models when appropriate. Make optionality explicit. Avoid force unwraps unless a documented invariant makes failure impossible. Prefer structured concurrency and async/await for asynchronous work. Keep domain code framework-light and testable.

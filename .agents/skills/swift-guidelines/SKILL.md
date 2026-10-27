---
name: swift-guidelines
description: >-
  Use this skill when writing or reviewing any Swift 6 code in SplitBill to follow
  project compiler settings, value semantics, typed errors, optionals safety, and
  Xcode 27 conventions.
---

# Swift 6 Guidelines — SplitBill

## When to Use
- **Agent**: Activate before writing or refactoring any `.swift` file in `apps/SplitBill/`.
- **Developer**: Reference to learn modern Swift 6 idioms used in this repository.
- **Complementary Skill**: Activate `swift-concurrency-pro` when working with `async/await`, `Task`, or actors.

## 1. Xcode 27 Compiler Settings in SplitBill
Our `apps/SplitBill/SplitBill.xcodeproj` has the following modern Swift build settings enabled by default:
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (types default to `@MainActor` unless marked `nonisolated`).
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`.

## 2. Core Coding Rules

1. **Value Types First**:
   - Use `struct` and `enum` for domain entities, events, and calculation outputs.
   - Use `final class` annotated with `@Observable` only when reference semantics are required for shared UI state.
2. **Explicit Optionals & Zero Force-Unwraps**:
   - Never use force-unwrap (`!`), `try!`, or `as!` in production code under `apps/SplitBill/SplitBill/`.
   - Handle optionality explicitly with `guard let`, `if let`, or nil-coalescing (`??`).
3. **Typed & Equatable Errors**:
   - Define domain-specific error enums conforming to `Error, Equatable, Sendable` so unit tests can assert exact error cases with `#expect(throws: DomainError.someCase)`.
4. **Access Control & Clarity**:
   - Keep properties `let` (immutable) whenever mutation is not required.
   - Prefer pure functions for business calculations: `Input -> Result/Output` with no hidden side effects.

## Verification Step
Compile and run tests via `./scripts/verify.sh` to confirm zero compiler warnings or errors.

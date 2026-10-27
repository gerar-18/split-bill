---
name: ios-testing
description: >-
  Use this skill when writing, running, or debugging unit and integration tests in
  apps/SplitBill/SplitBillTests/ or running ./scripts/verify.sh.
---

# iOS Testing Runbook — SplitBill

## When to Use
- **Agent**: Activate whenever writing or executing tests in `apps/SplitBill/SplitBillTests/`.
- **Developer**: Reference to run tests from the terminal or write parameterized tests with Swift Testing.
- **Complementary Skill**: Activate `swift-testing-pro` for advanced Swift Testing macros, traits, and async patterns.

## 1. How to Run Tests in SplitBill

Always prefer the project verification script from the repository root:

```bash
./scripts/verify.sh
```

Or run `xcodebuild test` directly when filtering a specific test suite:

```bash
xcodebuild test \
  -project apps/SplitBill/SplitBill.xcodeproj \
  -scheme SplitBill \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

> **Note for Agent Execution**: Because `xcodebuild test` communicates with the macOS `CoreSimulator` daemon outside the workspace directory, invoke `run_command` with `BypassSandbox: true` if sandbox mode blocks simulator access.

## 2. Swift Testing Conventions (`import Testing`)

All unit tests live in `apps/SplitBill/SplitBillTests/` and use **Swift Testing** (not `XCTest`):

```swift
import Testing
@testable import SplitBill

@Suite("Money & Splitting Calculations")
struct MoneyCalculationTests {

    @Test("Equal split distributes odd cents deterministically", arguments: [
        (totalCents: 1000, ways: 3, expected: [334, 333, 333]),
        (totalCents: 1,    ways: 2, expected: [1, 0]),
        (totalCents: 0,    ways: 3, expected: [0, 0, 0])
    ])
    func equalSplitOddCents(totalCents: Int64, ways: Int, expected: [Int64]) throws {
        // Arrange -> Act -> Assert with #expect
        #expect(expected.reduce(0, +) == totalCents)
    }
}
```

## 3. Mandatory Testing Rules
- Test domain rules directly without instantiating SwiftUI views.
- Include boundary and failure cases (`#expect(throws: DomainError.self) { ... }`).
- Never delete or weaken an existing test just to get a green build.

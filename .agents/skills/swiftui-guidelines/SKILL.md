---
name: swiftui-guidelines
description: >-
  Use this skill when building or modifying SwiftUI views, navigation, or @Observable
  view state in apps/SplitBill/SplitBill/UI/.
---

# SwiftUI Guidelines — SplitBill

## When to Use
- **Agent**: Activate when creating or updating SwiftUI screens in `apps/SplitBill/SplitBill/UI/`.
- **Developer**: Use when designing the manual split flow in M2 and beyond.
- **Complementary Skills**:
  - Activate `swiftui-pro` for comprehensive modern SwiftUI API verification and anti-deprecations.
  - Activate `mobile-ios-design` for Apple Human Interface Guidelines (HIG), layout ergonomics, and visual polish.

## 1. Strict Separation of Concerns (ADR-002)
- **Views (`View`)**: Describe layout, styling, accessibility, and user interaction bindings only.
- **Never** embed bill-splitting math, tax allocation, or rounding formulas inside a `View` body.
- **State Ownership**:
  - Use `@State` for view-owned value state or `@Observable` model instances.
  - Use `@Bindable` when creating two-way bindings to an `@Observable` object passed into a subview.
  - Do **not** use legacy `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject`.

## 2. Pattern Example

```swift
import SwiftUI

@Observable
final class ReceiptEditorViewModel {
    var items: [ReceiptItem] = []
    var participants: [Participant] = []

    // Delegates calculation to pure Domain engine
    var splitSummary: SplitSummary? {
        try? SplitEngine.calculate(items: items, participants: participants)
    }
}

struct ReceiptSummaryView: View {
    let viewModel: ReceiptEditorViewModel

    var body: some View {
        List {
            // Small, focused subviews
        }
        .navigationTitle("Split Bill")
    }
}

#Preview {
    NavigationStack {
        ReceiptSummaryView(viewModel: ReceiptEditorViewModel())
    }
}
```

## 3. Accessibility & Polish Requirements
- Every interactive icon-only button must include `.accessibilityLabel("...")`.
- Use system semantic colors (`.primary`, `.secondary`, `.background`) and Dynamic Type fonts (`.headline`, `.body`, `.monospacedDigit()` for currency amounts!) so Light/Dark mode and text scaling work out of the box.
- Always include a `#Preview` macro for every new screen or reusable view component.

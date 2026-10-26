# System Architecture

## Initial architecture

```text
SwiftUI
  ↓
Presentation / ViewModels
  ↓
Domain
  ├── Receipt
  ├── Money
  ├── Splitting
  └── Validation
  ↓
Infrastructure
  ├── SwiftData
  └── Vision (later)
```

The domain layer must not depend on SwiftUI.

## Future architecture

```text
iOS
  ↓ HTTPS
NestJS API
  ↓
PostgreSQL
```

OCR and LLM processing will be introduced only after the manual workflow is stable.

## Architecture principles

1. Local-first.
2. Explicit domain rules.
3. Deterministic calculations.
4. External services behind interfaces.
5. Validate AI output before domain application.

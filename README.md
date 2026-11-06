# SplitBill

[![CI Pipeline](https://github.com/gerar-18/split-bill/actions/workflows/ci.yml/badge.svg)](https://github.com/gerar-18/split-bill/actions/workflows/ci.yml)

SplitBill is a learning-driven iOS application designed for scanning restaurant receipts, assigning items among participants with multiple split modes, and calculating exact per-person totals using integer-based financial mathematics.

---

## 🎯 Project Goals

- **Modern iOS Architecture**: Pure Domain separation ([ADR-002](docs/decisions/ADR-002-domain-separation.md)), Swift 6 strict concurrency (`@MainActor`, `Sendable`), and reactive state using the Observation framework (`@Observable`).
- **Financial Precision**: Zero binary floating-point types (`Float`/`Double`) for money. All calculations use exact integer minor units (`Int64` cents/centavos) with the Hamilton largest-remainder method for deterministic penny allocation.
- **Local-First & Resilient ([ADR-001](docs/decisions/ADR-001-local-first.md))**: Full offline functionality with automated SwiftData persistence surviving app restarts.
- **App Store Release Strategy ([ADR-004](docs/decisions/ADR-004-appstore-release-strategy.md))**: Two-wave shipping model (v1.0 Local-First followed by v2.0 Cloud, AI Pro & Collaboration) adhering strictly to Apple Review Guidelines.
- **Production Quality**: Rigorous automated testing via `Swift Testing` (`@Test`, `#expect`), accessible Apple HIG design (VoiceOver, Dynamic Type), and continuous integration with GitHub Actions.

---

## 🗺️ Milestone Progress

### Wave 1 — v1.0 Local-First App Store Release

| Milestone | Target Version | Goal | Exit Criterion | Status |
|---|---|---|---|:---:|
| **M0** | `v0.0.1` | Engineering foundation | Repository, agent workflow, tests, documentation, CI-ready pipeline | ✅ Complete |
| **M1** | `v0.1.0` | Split engine | Deterministic business logic with comprehensive tests (Hamilton split math) | ✅ Complete |
| **M2** | `v0.2.0` | iOS UI | Complete manual split flow (4 split modes, tip presets, VoiceOver, ShareLink) | ✅ Complete |
| **M3** | `v0.3.0` | Persistence | Receipts survive app restarts (SwiftData, multi-receipt history, auto-save) | ✅ Complete |
| **M4** | `v0.4.0` | Camera | Capture and preview receipt image (Camera, PhotosPicker, Sample Receipts, Zoom) | ✅ Complete |
| **M5** | `v0.5.0` | OCR | Image to text with evaluation fixtures (Apple Vision, geometric line reconstruction) | ✅ Complete |
| **M6** | `v0.6.0` | Intelligent parsing | Deterministic receipt parser with real-time financial reconciliation & review sheet | ✅ Complete |
| **M6.5** | `v1.0.0` | **App Store v1.0 Release** | `PrivacyInfo.xcprivacy`, 1024px `AppIcon`, iPhone-only, Spanish metadata, in-app Privacy & Support, TestFlight/App Store | ✅ Complete |

### Wave 2 — v2.0 Cloud Sync, Paid LLM & Collaboration

| Milestone | Target Version | Goal | Exit Criterion | Status |
|---|---|---|---|:---:|
| **M7** | `v1.1.0` | Backend & Identity | NestJS + PostgreSQL cloud sync, optional *Sign in with Apple* (4.8), in-app account deletion (5.1.1(v)), backend LLM proxy | 📋 Planned |
| **M7.5** | `v1.2.0` | **AI Extraction & Monetization** | User AI consent modal (5.1.2(i)), `StoreKit 2` subscriptions/paywall (3.1.1/3.1.2), Restore Purchases, LLM parsing ([ADR-003](docs/decisions/ADR-003-ai-after-deterministic-parser.md)) | 📋 Planned |
| **M8** | `v1.3.0` | Collaboration | Shared receipt workflow via QR / Universal Links without forced guest login, UGC report/hide controls (1.2) | 📋 Planned |
| **M9** | `v2.0.0` | Production v2.0 | TestFlight, live backend SLA, App Review demo credentials (2.1), `MetricKit` crash/performance observability | 📋 Planned |

---

## 🏗️ Repository Structure

```text
split-bill/
├── .github/workflows/       # GitHub Actions CI pipeline (verify on push & tags)
├── apps/SplitBill/          # Native iOS Application
│   ├── SplitBill/
│   │   ├── Domain/          # Pure business logic (Receipt, SplitEngine, Money, DeterministicReceiptParser)
│   │   ├── Infrastructure/  # Persistence (SwiftData), OCR (Vision), Imaging (Processor, Samples)
│   │   └── UI/              # Views (Workspace, Review, OCR, Zoom) & Observable State
│   └── SplitBillTests/      # Swift Testing suites (124+ unit, evaluation & persistence tests)
├── docs/                    # Architecture (ADR), product roadmap, and quality strategy
│   ├── architecture/        # System architecture specifications
│   ├── decisions/           # Architecture Decision Records (ADR-001 to ADR-004)
│   ├── domain/              # Money calculation and splitting rules
│   ├── legal/               # Privacy policy & Support pages (App Store compliance)
│   ├── product/             # Roadmap and Product Vision
│   └── release/             # App Store release runbooks & checklists
├── scripts/                 # Verification scripts (verify.sh)
├── services/                # Future backend services (M7)
└── tests/fixtures/          # OCR datasets and evaluation fixtures
```

---

## 🧪 Verification & Continuous Integration

To run the complete verification suite locally (architecture boundary validation, build check, and Swift Testing):

```bash
./scripts/verify.sh
```

Every push, pull request to `main`, and version tag (`v*`) automatically runs `./scripts/verify.sh` on macOS runners via GitHub Actions, verifying:
1. **ADR-002 Architecture Boundary**: `apps/SplitBill/SplitBill/Domain/` contains zero occurrences of `import SwiftUI` and zero occurrences of `import SwiftData`.
2. **Financial Invariants**: `Domain/` contains zero occurrences of `Float` or `Double`.
3. **Swift 6 Compilation**: Zero warnings with deployment target iOS 18+.
4. **Swift Testing**: All 124+ automated tests pass.

---

## 📜 Development Principles

AI agents accelerate implementation; they do not replace engineering judgment. Every completed feature must satisfy its acceptance criteria, have appropriate automated tests, pass `./scripts/verify.sh`, and remain fully understandable by the project owner. Architectural decisions are documented in [`docs/decisions/`](docs/decisions/) and learning milestones in [`LEARNING_LOG.md`](LEARNING_LOG.md).

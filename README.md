# SplitBill

[![CI Pipeline](https://github.com/gerar-18/split-bill/actions/workflows/ci.yml/badge.svg)](https://github.com/gerar-18/split-bill/actions/workflows/ci.yml)

SplitBill is a learning-driven iOS application designed for scanning restaurant receipts, assigning items among participants with multiple split modes, and calculating exact per-person totals using integer-based financial mathematics.

---

## 🎯 Project Goals

- **Modern iOS Architecture**: Pure Domain separation ([ADR-002](docs/decisions/ADR-002-domain-separation.md)), Swift 6 strict concurrency (`@MainActor`, `Sendable`), and reactive state using the Observation framework (`@Observable`).
- **Financial Precision**: Zero binary floating-point types (`Float`/`Double`) for money. All calculations use exact integer minor units (`Int64` cents/centavos) with the Hamilton largest-remainder method for deterministic penny allocation.
- **Local-First & Resilient ([ADR-001](docs/decisions/ADR-001-local-first.md))**: Full offline functionality with automated SwiftData persistence surviving app restarts.
- **Production Quality**: Rigorous automated testing via `Swift Testing` (`@Test`, `#expect`), accessible Apple HIG design (VoiceOver, Dynamic Type), and continuous integration with GitHub Actions.

---

## 🗺️ Milestone Progress

| Milestone | Goal | Exit Criterion | Status |
|---|---|---|:---:|
| **M0** | Engineering foundation | Repository, agent workflow, tests, documentation, CI-ready pipeline | ✅ Complete |
| **M1** | Split engine | Deterministic business logic with comprehensive tests (Hamilton split math) | ✅ Complete |
| **M2** | iOS UI | Complete manual split flow (4 split modes, tip presets, VoiceOver, ShareLink) | ✅ Complete |
| **M3** | Persistence | Receipts survive app restarts (SwiftData, multi-receipt history, auto-save) | ✅ Complete |
| **M4** | Camera | Capture and preview receipt image (Camera, PhotosPicker, Sample Receipts, Zoom) | ✅ Complete |
| **M5** | OCR | Image to text with evaluation fixtures | ⏳ Next |
| **M6** | Intelligent parsing | OCR text to validated structured receipt | 📋 Planned |
| **M7** | Backend | Cloud synchronization | 📋 Planned |
| **M8** | Collaboration | Shared receipt workflow | 📋 Planned |
| **M9** | Production | TestFlight, observability, and release | 📋 Planned |

---

## 🏗️ Repository Structure

```text
split-bill/
├── .github/workflows/       # GitHub Actions CI pipeline (verify, test, summary)
├── apps/SplitBill/          # Native iOS Application
│   ├── SplitBill/
│   │   ├── Domain/          # Pure business logic (Receipt, SplitEngine, Money) [Zero UI/DB deps]
│   │   ├── Infrastructure/  # Persistence layer (StoredReceipt, SwiftDataReceiptStore)
│   │   └── UI/              # Views & State (ReceiptWorkspaceView, ReceiptEditorViewModel)
│   └── SplitBillTests/      # Swift Testing suites (71+ unit & persistence tests)
├── docs/                    # Architecture (ADR), product roadmap, and quality strategy
├── scripts/                 # Verification scripts (verify.sh)
├── services/                # Future backend services
└── tests/fixtures/          # OCR datasets and evaluation fixtures
```

---

## 🧪 Verification & Continuous Integration

To run the complete verification suite locally (architecture boundary validation, build check, and Swift Testing):

```bash
./scripts/verify.sh
```

Every push and pull request to `main` automatically runs `./scripts/verify.sh` on macOS runners via GitHub Actions, verifying:
1. **ADR-002 Architecture Boundary**: `apps/SplitBill/SplitBill/Domain/` contains zero occurrences of `import SwiftUI` and zero occurrences of `import SwiftData`.
2. **Financial Invariants**: `Domain/` contains zero occurrences of `Float` or `Double`.
3. **Swift 6 Compilation**: Zero warnings with deployment target iOS 18+.
4. **Swift Testing**: All 71+ automated tests pass.

---

## 📜 Development Principles

AI agents accelerate implementation; they do not replace engineering judgment. Every completed feature must satisfy its acceptance criteria, have appropriate automated tests, pass `./scripts/verify.sh`, and remain fully understandable by the project owner. Architectural decisions are documented in [`docs/decisions/`](docs/decisions/) and learning milestones in [`LEARNING_LOG.md`](LEARNING_LOG.md).

# Product Roadmap

## Wave 1 — v1.0 Local-First App Store Release

| Milestone | Target Version | Goal | Exit criterion | Status |
|---|---|---|---|:---:|
| **M0** | `v0.0.1` | Engineering foundation | Repository, agent workflow, tests, documentation, CI-ready project | ✅ Complete |
| **M1** | `v0.1.0` | Split engine | Deterministic business logic with comprehensive tests (Hamilton method) | ✅ Complete |
| **M2** | `v0.2.0` | iOS UI | Complete manual split flow with VoiceOver and Dynamic Type | ✅ Complete |
| **M3** | `v0.3.0` | Persistence | Receipts survive app restarts via SwiftData | ✅ Complete |
| **M4** | `v0.4.0` | Camera | Capture, normalize, and preview receipt image with zoom | ✅ Complete |
| **M5** | `v0.5.0` | OCR | On-device Vision image-to-text with geometric line reconstruction | ✅ Complete |
| **M6** | `v0.6.0` | Deterministic parsing | OCR text to validated structured receipt with human-in-the-loop review | ✅ Complete |
| **M6.5** | `v1.0.0` | **App Store v1.0 Release (Local-First)** | `PrivacyInfo.xcprivacy`, 1024px `AppIcon`, iPhone-only target, Spanish localization metadata, in-app Privacy/Support sheet, and TestFlight/App Store submission | ⏳ Next |

## Wave 2 — v2.0 Cloud Sync, Paid LLM & Collaboration

| Milestone | Target Version | Goal | Exit criterion | Status |
|---|---|---|---|:---:|
| **M7** | `v1.1.0` | Backend & Identity | NestJS + PostgreSQL cloud sync, optional *Sign in with Apple* (Guideline 4.8), in-app account deletion & token revocation (Guideline 5.1.1(v)), and backend LLM proxy | 📋 Planned |
| **M7.5** | `v1.2.0` | **AI Extraction & Monetization** | Third-party AI explicit user consent modal (Guideline 5.1.2(i)), `StoreKit 2` subscriptions/entitlements (Guidelines 3.1.1/3.1.2), Restore Purchases, and schema-validated LLM parsing (`ADR-003`) | 📋 Planned |
| **M8** | `v1.3.0` | Collaboration | Shared receipt workflow via QR / Universal Links (`Associated Domains`) without forced guest login, plus UGC report/hide controls (Guideline 1.2) | 📋 Planned |
| **M9** | `v2.0.0` | Production v2.0 | Live production backend SLA, App Review demo credentials (Guideline 2.1), `MetricKit` crash/performance observability, and v2.0 App Store release | 📋 Planned |

# Product Roadmap

## Wave 1 — v1.0 Local-First App Store Readiness & Portfolio Showcase

| Milestone | Target Version | Goal | Exit criterion | Status |
|---|---|---|---|:---:|
| **M0** | `v0.0.1` | Engineering foundation | Repository, agent workflow, tests, documentation, CI-ready project | ✅ Complete |
| **M1** | `v0.1.0` | Split engine | Deterministic business logic with comprehensive tests (Hamilton method) | ✅ Complete |
| **M2** | `v0.2.0` | iOS UI | Complete manual split flow with VoiceOver and Dynamic Type | ✅ Complete |
| **M3** | `v0.3.0` | Persistence | Receipts survive app restarts via SwiftData | ✅ Complete |
| **M4** | `v0.4.0` | Camera | Capture, normalize, and preview receipt image with zoom | ✅ Complete |
| **M5** | `v0.5.0` | OCR | On-device Vision image-to-text with geometric line reconstruction | ✅ Complete |
| **M6** | `v0.6.0` | Deterministic parsing | OCR text to validated structured receipt with human-in-the-loop review | ✅ Complete |
| **M6.5** | `v1.0.0` | App Store v1.0 Readiness | `PrivacyInfo.xcprivacy`, 1024px `AppIcon`, iPhone-only, encryption exemption, in-app Privacy/Support sheet | ✅ Complete |
| **M6.6** | `v1.0.0` | **Portfolio & Open-Source Showcase** | MIT License, CHANGELOG, visual assets in `docs/assets/`, deep-linked engineering README, and free sideloading guide | ✅ Complete |

## Wave 2 — Siguientes Hitos de Desarrollo a Costo $0 y Nube Futura

| Milestone | Target Version | Goal | Exit criterion | Status |
|---|---|---|---|:---:|
| **M6.7** | `v1.1.0` | **Visual Receipt Card Exporter (`ImageRenderer`)** | Render an infographic receipt summary card as PNG/PDF with custom branding, shareable directly to WhatsApp/iMessage | ⏳ Next |
| **M7** | `v1.2.0` | **Local Cloud Backend (Docker Compose)** | NestJS + PostgreSQL running locally at $0 cost via Docker Compose for receipt sync and optional Apple authentication | 📋 Planned |
| **M7.5** | `v1.3.0` | **AI Extraction Proxy** | Backend LLM proxy with domain validation, explicit user consent dialog (Guideline 5.1.2(i)), and local/free model support | 📋 Planned |
| **M8** | `v1.4.0` | Collaboration | Shared receipt workflow via QR / Universal Links without forced guest login, plus UGC report/hide controls (Guideline 1.2) | 📋 Planned |
| **M9** | `v2.0.0` | Production v2.0 & Commercial StoreKit 2 | Live production backend, App Review demo credentials, `MetricKit` observability, and live StoreKit 2 subscriptions | 📋 Planned |

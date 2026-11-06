# ADR-004 — Two-Wave App Store Release Strategy and Compliance Guardrails

Status: Accepted

## Context

By milestone `M6`, SplitBill has achieved a fully functional, offline-first product:
- Exact penny division with the Hamilton largest-remainder method (`SplitEngine`).
- SwiftData automated multi-receipt persistence.
- Camera receipt capture, photo picker, and pinch-to-zoom viewer.
- On-device Apple Vision text recognition with geometric line reconstruction.
- Deterministic regex receipt parser with real-time financial reconciliation and human-in-the-loop review.

Originally, release planning was postponed to `M9` (after building a NestJS backend and multi-user collaboration). However, publishing `v1.0 Local-First` immediately unlocks real-world validation, user feedback, and App Store readiness with zero server operating costs and zero external API dependencies.

Furthermore, shipping to the App Store requires strict compliance with Apple Review Guidelines regarding packaging, privacy declarations, user consent, in-app purchases, and account lifecycle management.

---

## Decision

Adopt a **Two-Wave Release Strategy** with strict engineering and compliance guardrails:

### 1. Wave 1: Milestone M6.5 — v1.0 Local-First Release
Release a 100% on-device application before developing backend infrastructure:
- **Platform Scope**: Restrict `v1.0` exclusively to iPhone (`TARGETED_DEVICE_FAMILY = "1"` and `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`). This eliminates the mandatory requirement for 13" iPad screenshots and visionOS audits during initial review.
- **Privacy Manifest**: Include `PrivacyInfo.xcprivacy` declaring `NSPrivacyTracking = false`, empty tracking domains, and zero off-device data collection.
- **Branding & Assets**: Provide a 1024×1024 px PNG icon in `AppIcon.appiconset` with no alpha channel.
- **Localization Alignment**: Set `CFBundleDevelopmentRegion = es` (or `es-419`) in build settings to align store listing metadata with the application's actual UI and camera permission text.
- **Legal & Transparency**: Add an in-app "About & Privacy" view in `ReceiptWorkspaceView` with functional links to a hosted Privacy Policy and Support page.
- **Export Compliance**: Set `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in Xcode configuration.

### 2. Wave 2: Milestones M7 to M9 — v2.0 Cloud, AI Pro & Collaboration
Introduce cloud services, paid LLM parsing, and shared receipts while preserving full offline functionality:
- **Non-Gated Core Usage (Guideline 4.0)**: Never require an account or internet connection for manual receipt calculation or local parsing.
- **Identity & Account Deletion (Guidelines 4.8 & 5.1.1(v))**: When cloud sync is used, offer *Sign in with Apple* as an optional sign-in method and provide an in-app button to permanently delete the account, cascade-delete records in PostgreSQL, and revoke Apple authorization tokens.
- **In-App Purchases (Guidelines 3.1.1 & 3.1.2)**: Cloud LLM extraction must be monetized using `StoreKit 2` with a compliant paywall, clear subscription terms, and a "Restore Purchases" button (`AppStore.sync()`).
- **Explicit AI Consent (Guideline 5.1.2(i))**: Present an explicit user consent prompt prior to sending any receipt images or text to a third-party AI provider.
- **Frictionless Collaboration & UGC (Guideline 1.2)**: Shared receipts use QR codes / Universal Links where guests can claim items without account creation, accompanied by controls to hide receipt images or report inappropriate content.

### 3. Git Versioning & Release Discipline
- Use Semantic Versioning (`vMAJOR.MINOR.PATCH`) mapped directly to `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode.
- Tag every completed milestone and release candidate with annotated Git tags (`git tag -a vX.Y.Z -m "..."`).
- Publish structured GitHub Releases with release notes, invariant verification summaries, and test counts.

---

## Consequences

### Positive
- **Fast Path to Market**: Validates the production pipeline (certificates, Provisioning Profiles, App Store Connect, TestFlight) immediately.
- **Zero Running Costs**: `v1.0` incurs $0 in server hosting, database, and LLM inference expenses.
- **Zero Rework**: Prevents architectural dead-ends by planning account deletion, StoreKit 2, and AI proxy boundaries before writing backend code.
- **Audit-Proof Compliance**: Eliminates the most common App Store rejections (broken placeholders, missing Privacy Manifest, unapproved payment mechanisms, missing account deletion).

### Trade-offs
- iPad and visionOS native support is postponed to a post-v1.0 release after formal UI adaptation.
- Real-time multi-device collaboration is deferred to Wave 2.

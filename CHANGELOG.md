# Changelog

All notable changes to **SplitBill** are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-11-06

### Added
- **Visual Receipt Card Exporter (`ImageRenderer`) (M6.7)**:
  - High-resolution Retina infographic receipt card view (`ReceiptShareCardView`) rendering at 3.0x scale (1140 px width) via `SwiftUI.ImageRenderer`.
  - Dynamic card styling with two native themes: **Clásico** (Classic Light) and **Nocturno** (Midnight Dark).
  - Detail granularity toggle allowing users to include or omit itemized dish breakdowns per participant.
  - Native file sharing via `CoreTransferable` (`ShareableReceiptImage`) exporting actual `.png` image files with thumbnail previews to WhatsApp, iMessage, AirDrop, and Photos.
  - Interactive preview sheet (`ReceiptSharePreviewSheet`) integrated into `SplitSummarySectionView` and top toolbar sharing menu in `ReceiptWorkspaceView`.
  - Automated test suite `ReceiptShareCardTests` covering Master Conservation Invariant, bystander participant handling, and valid PNG byte header verification.

---

## [1.0.0] - 2026-11-06

### Added
- **App Store Packaging & Compliance (M6.5)**:
  - Official Apple Privacy Manifest (`PrivacyInfo.xcprivacy`) declaring zero off-device tracking and zero data collection.
  - Native 1024×1024 px master App Icon with RGB color space and zero alpha channel (`hasAlpha: no`).
  - Automatic export compliance declaration (`ITSAppUsesNonExemptEncryption = NO`).
  - In-app **About & Privacy modal (`AboutPrivacySheet`)** with verified links to Privacy Policy and Support pages (Guidelines 1.5 & 5.1.1(i)).
  - Automated test suite `AppBundleComplianceTests` with 5 tests verifying bundle integrity, localization, and privacy keys.
  - Complete App Store Connect checklist and review notes (`docs/release/appstore-v1-checklist.md`).
- **Portfolio & Open-Source Showcase (M6.6)**:
  - Official MIT License and public issue tracker links.
  - High-resolution visual screenshots in `docs/assets/`.
  - Comprehensive portfolio README with deep links to architecture highlights.
  - Step-by-step free sideloading guide for installing directly onto physical iPhones via Xcode Personal Team ($0 cost).

### Changed
- Restricted targeted device family to iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) and supported platforms to `iphoneos iphonesimulator`.
- Set primary development region to Spanish (`developmentRegion = es`) to align with UI and camera permission text.
- Cleaned up obsolete macOS sandbox and App Group flags from `project.pbxproj`.
- Polished accessibility labels to eliminate test artifacts in production views.

---

## [0.6.0] - 2026-11-06

### Added
- **Intelligent Deterministic Parsing (M6)**:
  - `DeterministicReceiptParser` utilizing regular expressions, positional heuristics, and lookbehind analysis.
  - Real-time mathematical reconciliation engine ($\sum \text{items} + \text{tax} == \text{total}$) with diagnostic states (`.verified`, `.discrepancy`, `.partial`).
  - Human-in-the-loop review sheet (`ReceiptParsedReviewSheet`) with inline participant quick-entry.
  - Safe import modes (replace vs. append) and equal initial allocation across active participants.
  - Integration tests in `ReceiptEditorViewModelParsingTests` and parser suite `ReceiptParserTests`.

---

## [0.5.0] - 2026-11-05

### Added
- **On-Device Optical Character Recognition (M5)**:
  - Native Apple `Vision` framework text recognition running on the Apple Neural Engine (`VNRecognizeTextRequest`).
  - Geometric row clustering (`ReceiptOCRLineGrouper`) aligning item names and prices across horizontal rows with coordinate normalization.
  - OCR raw text persistence in `StoredReceipt` and `ReceiptSnapshot`.
  - Actor reentrancy guard in `ReceiptEditorViewModel` protecting against race conditions during asynchronous scanning.
  - Interactive OCR inspection sheet (`ReceiptOCRTextSheet`) with accessible line-by-line inspection and clipboard export.
  - Automated evaluation fixtures over synthetic receipts (`ReceiptOCREvaluationTests`).

---

## [0.4.0] - 2026-11-04

### Added
- **Camera Capture & Image Inspection (M4)**:
  - Native camera capture sheet with fallback availability detection (`CameraCaptureView`).
  - Out-of-process photo library picker (`PhotosPicker`) avoiding intrusive permissions.
  - Full-screen pinch-to-zoom interactive receipt viewer (`ReceiptImageViewerSheet`).
  - Synthetic receipt generator (`SampleReceiptImageGenerator`) for offline testing in simulator environments.

---

## [0.3.0] - 2026-11-02

### Added
- **Local Persistence with SwiftData (M3)**:
  - Multi-receipt persistence surviving app restarts (`StoredReceipt`, `ReceiptSnapshot`).
  - In-memory fallback container (`SwiftDataReceiptStore.live()`) preventing startup crashes.
  - Saved receipts history sheet (`ReceiptHistorySheet`) with swipe-to-delete and receipt switching.
  - Automated persistence test suite (`ReceiptPersistenceTests`).

---

## [0.2.0] - 2026-10-30

### Added
- **Interactive SwiftUI Workspace (M2)**:
  - Reactive state management with Apple's `Observation` framework (`@Observable ReceiptEditorViewModel`).
  - Support for 4 split modes: even, percentage, exact amount, and shares.
  - Dynamic tax and tip allocation (preset percentages 10%, 15%, 20% or custom amounts) with proportional vs. equal distribution.
  - Full VoiceOver annotations, Dynamic Type scaling, and Dark Mode contrast compliance.
  - Native `ShareLink` exporting plain-text bill breakdowns for messaging apps.

---

## [0.1.0] - 2026-10-28

### Added
- **Exact Financial Split Engine (M1)**:
  - Exact minor-unit currency representation (`Money` using `Int64` cents) avoiding binary floating-point errors (`ADR-002`).
  - Penny-exact allocation using the **Hamilton largest-remainder method** (`SplitEngine`).
  - Master conservation invariant: $\sum \text{allocated} == \text{receipt total}$.
  - Comprehensive unit test suite (`ReceiptSplitEngineTests`, `ItemSplitTests`, `MoneyTests`).

---

## [0.0.1] - 2026-10-26

### Added
- **Engineering Foundation (M0)**:
  - Repository structure with strict domain separation (`Domain/` with zero UI/database imports).
  - Automated verification pipeline script (`./scripts/verify.sh`).
  - GitHub Actions CI workflow running on macOS runners.
  - Agent and skill routing system (`.agents/`).

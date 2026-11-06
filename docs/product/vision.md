# Product Vision

## Problem

Splitting a restaurant bill is tedious when products are shared, taxes and tips must be allocated, and the receipt is difficult to parse manually.

## Vision

Make bill splitting feel like a short, delightful mobile workflow:

**Scan → Review → Assign → Split → Share**

---

## Release Scope

### Wave 1 — MVP & v1.0 Local-First App Store Release

The first release focuses on a private, resilient, offline-first experience with zero server operating costs:
- **Financial Precision**: Minor-unit integer math with the Hamilton largest-remainder method for penny-accurate split totals.
- **Assignment & Splitting**: 4 split modes (even, percentage, exact amount, shares), tax/tip allocation, and transparent per-person summaries.
- **Local Persistence**: SwiftData automatic save and multi-receipt history surviving app restarts.
- **Camera & Image Viewer**: Photo capture, gallery selection, synthetic sample tickets, and pinch-to-zoom inspection.
- **On-Device OCR & Deterministic Parsing**: Apple Vision text recognition with geometric line reconstruction and regular-expression based parsing with human-in-the-loop review.
- **App Store Readiness**: Privacy Manifest (`PrivacyInfo.xcprivacy`), 1024×1024 icon, Spanish metadata alignment, and in-app privacy & support disclosures.

### Wave 2 — v2.0 Cloud Sync, Paid LLM Extraction & Collaboration

The second phase expands SplitBill into a multi-device collaborative tool:
- **Cloud Synchronization**: Optional sync backed by NestJS and PostgreSQL without locking local offline usage behind a mandatory login.
- **Privacy-First Identity**: Sign in with Apple and in-app account deletion with cryptographic token revocation (Apple Guidelines 4.8 and 5.1.1(v)).
- **LLM-Assisted Extraction & Monetization**: Complex and unstructured receipt parsing executed securely behind the backend proxy, unlocked via StoreKit 2 subscriptions and preceded by explicit user consent (Apple Guidelines 3.1.1 and 5.1.2(i)).
- **Real-Time Collaboration**: Session sharing via Universal Links / QR codes without requiring guests to create accounts, protected by UGC report and hide controls (Apple Guideline 1.2).

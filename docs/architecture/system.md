# System Architecture

## Wave 1 Architecture — v1.0 Local-First

In `v1.0`, SplitBill operates entirely on-device with zero external network dependencies, ensuring maximum privacy, zero server running costs, and full offline resilience.

```text
SwiftUI Views (ReceiptWorkspaceView, ReceiptParsedReviewSheet, etc.)
  ↓ (Observation / State Binding)
Presentation / ViewModels (ReceiptEditorViewModel)
  ↓ (Pure Models & Ports)
Domain (Pure Swift, zero UI/DB imports)
  ├── Receipt, ReceiptItem, Participant, Assignment
  ├── Money (Minor-unit Int64 cents)
  ├── SplitEngine (Hamilton largest-remainder method)
  ├── DeterministicReceiptParser & MoneyParser
  └── ParsedReceiptReviewDraft (Human-in-the-loop review)
  ↓ (Inversion of Control)
Infrastructure
  ├── Persistence: SwiftDataReceiptStore & StoredReceipt
  ├── Imaging: ReceiptImageProcessor & SampleReceiptImageGenerator
  └── OCR: ReceiptOCRService (Apple Vision text recognition)
```

The domain layer must never depend on SwiftUI or SwiftData ([ADR-002](file:///Users/gera/Documents/Proyects/split-bill/docs/decisions/ADR-002-domain-separation.md)).

---

## Wave 2 Architecture — v2.0 Cloud, AI Pro & Collaboration

In `v2.0`, SplitBill adds multi-device sync, paid LLM parsing, and collaboration while preserving full local-first offline usability for non-authenticated users.

```text
iOS Client (SplitBill v2.0)
  ├── Core Domain & SwiftData (Local-First baseline)
  ├── AuthenticationServices (Sign in with Apple — Optional)
  ├── StoreKit 2 (In-App Subscriptions for AI Pro)
  └── Network Service (HTTPS client with JWT / JWS auth)
         │
         │ HTTPS / TLS 1.3
         ▼
NestJS API Gateway
  ├── Auth Controller (Apple Identity Verification & Token Revocation)
  ├── Entitlement Guard (StoreKit 2 JWS Cryptographic Verification)
  ├── LLM Proxy Service (Rate-limited, zero API keys on client)
  │      └── DeepSeek / Ollama / Heuristic Fallback Provider
  └── Shared Collaboration Module (SSE Live Stream + REST Optimistic Locking)
         ├── Anonymous SHA-256 Capability Tokens (No forced guest login)
         ├── Additive Item Claims (`expectedVersion` -> `409 Conflict`)
         └── UGC Moderation & Auto-Quarantine (Apple Guideline 1.2)
         │
         ▼
PostgreSQL Database
  ├── Users (Apple sub identifier, cascade delete)
  ├── Receipts & Items (`BIGINT` minor units)
  └── SharedSessions, SharedParticipants & SessionReports (24h TTL)
```

---

## Architecture Principles for App Store Compliance

1. **Local-First Baseline**: Never gate core offline receipt calculation or manual splitting behind a login wall (Apple Guideline 4.0).
2. **Zero Third-Party AI Keys on Client**: All generative AI calls must route through the backend proxy with authentication, rate limiting, and domain schema validation ([ADR-003](file:///Users/gera/Documents/Proyects/split-bill/docs/decisions/ADR-003-ai-after-deterministic-parser.md)).
3. **Explicit AI Consent**: Prompt users with explicit disclosures before transmitting receipt image or text to external AI providers (Apple Guideline 5.1.2(i)).
4. **Native In-App Monetization**: Any digital features unlocked by payment must use `StoreKit 2` with a compliant paywall, terms, privacy policy, and a "Restore Purchases" button (Apple Guidelines 3.1.1 and 3.1.2).
5. **Privacy-First Identity & Account Deletion**: If accounts are created in `M7`, offer Sign in with Apple (Guideline 4.8) and provide an in-app button to permanently delete the account, cascade-delete server data, and revoke Apple tokens (Apple Guideline 5.1.1(v)).
6. **Frictionless Collaboration**: Guests join shared bills via QR code or Universal Link without forced account creation, with built-in controls to hide images or report abusive receipts (Apple Guideline 1.2).

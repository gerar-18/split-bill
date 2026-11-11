---
name: backend-guidelines
description: >-
  Use this skill when designing, implementing, or reviewing backend services, APIs,
  database schemas, Docker containers, or sync protocols for SplitBill in services/api/.
---

# Backend Guidelines — SplitBill Server & Sync Architecture

## When to Use
- **Agent**: Activate when implementing or reviewing backend endpoints, database migrations, Docker Compose services, or sync protocol handlers under `services/api/`.
- **Developer**: Reference when defining API contracts, designing PostgreSQL tables, or integrating iOS client sync with the backend.

---

## 1. Core Principles & Business Invariants

### A. Monetary Representation (`ADR-002` Extension)
- **Zero Floating-Point in Storage or Transport**:
  - In PostgreSQL schemas, monetary columns must be defined strictly as `BIGINT NOT NULL` (representing minor units / centavos, e.g., `$10.50` -> `1050`).
  - Never use `FLOAT`, `REAL`, `DOUBLE PRECISION`, or unconstrained numeric types for money.
  - In JSON DTOs, represent amounts as integer minor units:
    ```typescript
    export class MoneyDto {
      @IsInt()
      @Min(0)
      minorUnits: number;

      @IsISO4217CurrencyCode()
      currency: string;
    }
    ```
- **Reconciliation Invariant**:
  - The sum of item allocations, taxes, and tips must reconcile to the exact receipt total:
    $$\sum \text{allocated} + \text{tax} + \text{tip} == \text{total}$$

### B. Local-First & Idempotent Synchronization (`ADR-004`)
- **Offline-First Resilience (Apple Guideline 4.0)**:
  - SplitBill client functionality must never be blocked by backend unavailability or login requirements.
  - Receipts are created locally first with a client-generated `UUID` (`clientReceiptId`).
- **Idempotency**:
  - Sync endpoints (`PUT /v1/receipts/:id` or `POST /v1/sync`) must be fully idempotent. Re-transmitting the same receipt payload multiple times must produce identical database states without duplicating records.
  - Use `updatedAt` timestamps or monotonic version numbers for conflict resolution (Client-Wins or Last-Write-Wins with explicit audit log).

### C. Security, Privacy & App Store Compliance
- **Zero Third-Party AI Keys on Client (`ADR-003`)**:
  - Client iOS apps never store OpenAI, Anthropic, or Gemini API keys.
  - The NestJS backend acts as a rate-limited, schema-validating proxy (`POST /v1/receipts/parse-ai`).
- **User Consent & Privacy (Apple Guideline 5.1.2(i))**:
  - Explicit user confirmation is required before forwarding receipt text or images to external AI services.
- **Account Deletion & Data Purge (Apple Guideline 5.1.1(v))**:
  - Provide `DELETE /v1/users/me` with cascade deletion (`ON DELETE CASCADE`) across receipts, participants, and session tokens.
  - Support Apple token revocation via Sign in with Apple REST APIs.

---

## 2. Directory Structure (`services/api/`)

```text
services/api/
├── docker-compose.yml       # Local PostgreSQL + NestJS environment
├── Dockerfile               # Production multi-stage Docker build
├── src/
│   ├── app.module.ts
│   ├── common/              # Filters, interceptors, guards, decorators
│   │   ├── filters/all-exceptions.filter.ts
│   │   └── guards/auth.guard.ts
│   ├── config/              # Environment validation (Zod or Joi)
│   ├── modules/
│   │   ├── receipts/        # Receipt sync, models, DTOs
│   │   ├── auth/            # Sign in with Apple JWS verification
│   │   ├── ai-proxy/        # LLM parsing proxy with schema validation
│   │   └── collaboration/   # WebSocket / ephemerals for shared sessions
│   └── database/            # Migrations, seeds, entities
└── test/                    # Unit & E2E tests (Jest / Supertest / fast-check)
```

---

## 3. NestJS Standards Checklist

1. **Strict Dependency Injection**: Inject services through constructor parameters; avoid global state or direct instantiations.
2. **DTO Validation**: Every controller endpoint must validate incoming payloads using `ValidationPipe` with `whitelist: true`, `forbidNonWhitelisted: true`, and `transform: true`.
3. **Centralized Error Handling**: Use custom HTTP exception filters that format errors consistently without leaking internal database stack traces:
   ```json
   {
     "statusCode": 400,
     "error": "Bad Request",
     "message": "Invalid minor units: must be non-negative integer",
     "timestamp": "2026-11-10T22:30:00Z"
   }
   ```
4. **Environment Isolation**: Read configurations strictly via `@nestjs/config` backed by validated environment schemas. Never hardcode ports, credentials, or secrets.

---
name: project-guidelines
description: >-
  Use this skill at the start of any task in SplitBill to navigate repository conventions,
  architecture boundaries, documentation routing, Xcode project structure, and the
  Definition of Done.
---

# Project Guidelines — SplitBill Runbook

## When to Use
- **Agent**: Activate at the beginning of any feature, bugfix, planning session, or review to locate the authoritative docs and verify the Definition of Done.
- **Developer**: Reference when checking where new files belong or which milestone criteria apply.

## 1. Repository Map

| Path | Purpose | Key Rules |
|---|---|---|
| `AGENTS.md` | Global agent constitution | Always-on rules; read before any change. |
| `apps/SplitBill/SplitBill/Domain/` | Pure business logic & entities | **Never** `import SwiftUI` (ADR-002). No `Float`/`Double` for money. |
| `apps/SplitBill/SplitBill/UI/` | SwiftUI screens, components & `@Observable` state | Presentation only; delegates calculations to `Domain/`. |
| `apps/SplitBill/SplitBillTests/` | Unit test suite (`Swift Testing`) | Uses `import Testing`, `@Test`, and `#expect`. |
| `scripts/verify.sh` | Automated verification gate | Checks ADR-002 boundaries, builds app, and runs unit tests. |
| `docs/` | Product, ADRs, domain & quality specs | Single source of truth for requirements and architecture. |
| `LEARNING_LOG.md` | Developer learning journal | Update after completing each milestone or new technical concept. |

## 2. Documentation Routing Table

Read only the `docs/` pages needed for your current task:
- **Product & Milestones** → `docs/product/vision.md`, `docs/product/roadmap.md`
- **System Architecture & ADRs** → `docs/architecture/system.md`, `docs/decisions/ADR-*.md`
- **Money & Splitting Rules** → `docs/domain/money-and-splitting.md`
- **Testing & Invariants** → `docs/quality/testing-strategy.md`
- **Agent & Skill Catalog** → `docs/ai/agents-and-skills.md`, `docs/ai/agent-workflow.md`

## 3. Standard Task Workflow

1. **Plan**: Read relevant docs → clarify assumptions → define acceptance criteria and small tasks (`planner`).
2. **Implement**: Write the smallest coherent code change in `apps/SplitBill/` (`ios-engineer`).
3. **Verify**: Run `./scripts/verify.sh` and add edge-case tests (`qa-engineer`).
4. **Review**: Audit `git diff` for invariants, architecture, and security (`code-reviewer`).
5. **Learn & Commit**: Record new concepts in `LEARNING_LOG.md` and commit using `git-workflow`.

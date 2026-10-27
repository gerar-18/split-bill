# AGENTS.md — SplitBill

## Mission

Build SplitBill as a modern, testable, privacy-conscious iOS product while using agents as specialized engineering collaborators and active learning mentors.

## Before changing code

1. Read the relevant product and architecture documentation (`project-guidelines`).
2. Identify the smallest coherent change.
3. State assumptions when requirements are ambiguous.
4. Prefer official Apple documentation for platform APIs.
5. Do not invent APIs, framework behavior, or test results.

## Engineering rules

- Keep domain logic (`apps/SplitBill/SplitBill/Domain/`) independent from SwiftUI (`ADR-002`).
- Do not represent money with binary floating point (`Float`/`Double`) in the domain model.
- Business rules require automated unit tests in `apps/SplitBill/SplitBillTests/` using Swift Testing (`@Test`, `#expect`).
- Always verify changes by running `./scripts/verify.sh`.
- Do not remove or weaken tests merely to make a build pass.
- Avoid unrelated refactors.
- Prefer small, reviewable changes.
- Preserve existing behavior unless the task explicitly changes it.

## Subagent & Skill Routing Matrix (When to Use What)

### Subagents (`.agents/agents/`)

| Subagent | When the Agent Invokes It | How the Developer Uses It |
|---|---|---|
| `planner` | Before implementing any non-trivial feature, milestone (`M1`–`M9`), or domain design. | `/plan` or *"Diseña el plan de [feature] con `planner`"* |
| `ios-engineer` | To write or modify Swift/SwiftUI code in `apps/SplitBill/` following an approved plan. | *"Implementa la tarea X con `ios-engineer`"* |
| `qa-engineer` | To design edge-case tests, verify financial invariants, and run `./scripts/verify.sh`. | *"Valida los casos borde de [feature] con `qa-engineer`"* |
| `code-reviewer` | Before committing/merging to audit `git diff` for bugs, ADRs, and security (read-only). | *"Revisa mis cambios con `code-reviewer`"* |

### Skills (`.agents/skills/`) — Activate by Task Context

| Task / Context | Project Skills to Activate (SplitBill Rules) | Community Skills to Activate (Tech Mastery) |
|---|---|---|
| **Starting any task / navigating repo** | `project-guidelines` | — |
| **Domain entities (`Receipt`, `Person`, `SplitMode`)** | `domain-modeling`, `swift-guidelines` | — |
| **Money, tax, tip, rounding & split math** | `money-calculation`, `domain-modeling` | — |
| **SwiftUI screens, `@Observable` & navigation** | `swiftui-guidelines`, `swift-guidelines` | `swiftui-pro`, `mobile-ios-design` |
| **Async/await, actors & `@MainActor` isolation** | `swift-guidelines` | `swift-concurrency-pro` |
| **Writing or running unit tests (`SplitBillTests`)** | `ios-testing` | `swift-testing-pro` |
| **Code review, security & privacy audit** | `project-guidelines`, `swift-guidelines` | `security-review` |
| **Staging, committing or branching in Git** | `git-workflow` | — |

## Agent workflow

For non-trivial work:

1. **Planner (`planner`)**: requirements, risks, acceptance criteria, task breakdown, and learning checkpoint.
2. **Implementer (`ios-engineer`)**: smallest implementation that satisfies the approved plan + `./scripts/verify.sh`.
3. **QA (`qa-engineer`)**: Swift Testing unit tests and financial edge cases + `./scripts/verify.sh`.
4. **Reviewer (`code-reviewer`)**: architecture, maintainability, security (`security-review`), and regression review.
5. **Human**: final review, commit (`git-workflow`), and `LEARNING_LOG.md` entry.

## Definition of Done

- Acceptance criteria satisfied.
- Relevant tests added or updated in `SplitBillTests`.
- `./scripts/verify.sh` passes completely.
- No unrelated changes.
- Documentation updated when needed.
- Reviewer concerns addressed.
- Human can explain the change at a high level.

## Learning rule

When a feature introduces a new concept, explain the "why" clearly to the developer and record in `LEARNING_LOG.md`:
- what was learned;
- what the agent implemented;
- what was manually reviewed or changed;
- what remains unclear.

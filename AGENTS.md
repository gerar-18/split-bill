# AGENTS.md — SplitBill

## Mission

Build SplitBill as a modern, testable, privacy-conscious iOS product while using agents as specialized engineering collaborators.

## Before changing code

1. Read the relevant product and architecture documentation.
2. Identify the smallest coherent change.
3. State assumptions when requirements are ambiguous.
4. Prefer official Apple documentation for platform APIs.
5. Do not invent APIs, framework behavior, or test results.

## Engineering rules

- Keep domain logic independent from SwiftUI.
- Do not represent money with binary floating point in the domain model.
- Business rules require automated tests.
- Do not remove or weaken tests merely to make a build pass.
- Avoid unrelated refactors.
- Prefer small, reviewable changes.
- Preserve existing behavior unless the task explicitly changes it.

## Agent workflow

For non-trivial work:

1. Planner: requirements, risks, acceptance criteria, task breakdown.
2. Implementer: smallest implementation that satisfies the approved plan.
3. QA: tests and edge cases.
4. Reviewer: architecture, maintainability, security, and regression review.
5. Human: final review and learning-log entry.

## Definition of Done

- Acceptance criteria satisfied.
- Relevant tests added or updated.
- Relevant tests pass.
- No unrelated changes.
- Documentation updated when needed.
- Reviewer concerns addressed.
- Human can explain the change at a high level.

## Learning rule

When a feature introduces a new concept, record:
- what was learned;
- what the agent implemented;
- what was manually reviewed or changed;
- what remains unclear.

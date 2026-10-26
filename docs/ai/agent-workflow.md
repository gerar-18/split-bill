# Agent Workflow

## Roles

- `planner` — decomposes work and defines acceptance criteria.
- `ios-engineer` — implements Swift/iOS work.
- `qa-engineer` — validates behavior and edge cases.
- `code-reviewer` — reviews implementation quality and architecture.

## Workflow

Requirement → Plan → Human approval → Implementation → Tests → QA → Review → Human merge.

## Rules

Agents must not claim a command, test, build, or external lookup succeeded unless it actually ran and produced the claimed result.

Agents should make the smallest change that satisfies the task.

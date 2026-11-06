---
name: git-workflow
description: >-
  Use this skill before staging, committing, or branching in SplitBill to enforce
  conventional commits, pre-commit verification, and repository hygiene.
---

# Git Workflow — SplitBill

## When to Use
- **Agent**: Activate before running `git add`, `git commit`, `git tag`, or `git checkout -b`.
- **Developer**: Use to keep commit history clean, atomic, reviewable, and aligned with releases.

## 1. Pre-Commit Checklist (Mandatory)

Before every commit, run:
1. `./scripts/verify.sh` — Confirm architecture check, build, and unit tests pass.
2. `git status` — Verify no untracked temporary files, `xcuserdata/`, `.DS_Store`, or nested `.git` folders are staged.
3. Update `LEARNING_LOG.md` if the change completes a milestone task or introduces a new concept.

## 2. Commit Message Convention

Use imperative **Conventional Commits**:
- `feat: add Money value type with minor-unit representation`
- `test: cover odd-cent allocation with parameterized tests`
- `fix: preserve receipt total when tax rounds on half-cent`
- `docs: document M1 split engine invariants`
- `chore: update agent skills and verification script`

## 3. Branching & Hygiene Rules
- Keep commits small and focused on a single coherent change.
- Never commit `xcuserdata/`, `.build/`, `DerivedData/`, or `.env` files.
- Never initialize a nested `.git` repository inside subdirectories like `apps/SplitBill/`.
- Never rewrite published history (`git push --force`) unless explicitly requested by the user.

## 4. Semantic Versioning, Annotated Tags & GitHub Releases

To maintain professional traceability between Git history and App Store releases ([ADR-004](file:///Users/gera/Documents/Proyects/split-bill/docs/decisions/ADR-004-appstore-release-strategy.md)):

### Versioning Mapping

| Git Tag Pattern | Meaning | Xcode `MARKETING_VERSION` | Xcode `CURRENT_PROJECT_VERSION` |
|---|---|---|---|
| `v0.<M>.0` (e.g. `v0.6.0`) | Completed foundation milestones (`M0`–`M6`) | `0.<M>.0` | Sequential milestone integer |
| `v1.0.0-rc.<N>` | TestFlight Release Candidate | `1.0.0` | Build number `<N>` |
| `v1.0.0` | Production App Store v1.0 (Wave 1) | `1.0.0` | Approved build number |
| `v1.x.0` / `v2.0.0` | Wave 2 milestones & releases (`M7`–`M9`) | SemVer `MAJOR.MINOR.PATCH` | Monotonic build number |

### Tagging Procedure

1. Always use **annotated tags**:
   ```bash
   git tag -a v0.6.0 -m "Release v0.6.0: M0-M6 Local-First Engine, Vision OCR & Deterministic Parser"
   ```
2. Push tags explicitly:
   ```bash
   git push origin v0.6.0
   ```
3. Create a GitHub Release using the GitHub CLI:
   ```bash
   gh release create v0.6.0 --title "v0.6.0 — Milestone M6: Intelligent Parsing Baseline" --notes-file release_notes.md
   ```

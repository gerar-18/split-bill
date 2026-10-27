---
name: git-workflow
description: >-
  Use this skill before staging, committing, or branching in SplitBill to enforce
  conventional commits, pre-commit verification, and repository hygiene.
---

# Git Workflow — SplitBill

## When to Use
- **Agent**: Activate before running `git add`, `git commit`, or `git checkout -b`.
- **Developer**: Use to keep commit history clean, atomic, and reviewable.

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

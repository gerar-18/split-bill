# SplitBill

SplitBill is a learning-driven iOS project for scanning restaurant receipts, splitting items between people, and calculating each participant's final amount.

## Project goals

- Learn modern iOS development with Swift and SwiftUI.
- Build a production-oriented product incrementally.
- Experiment with OCR, structured LLM extraction, and agentic software development.
- Practice testing, architecture, CI/CD, security, and observability.

## Current milestone

**M0 — Engineering Foundation**

The first implementation target is a local-first manual bill splitter. OCR and backend work come later.

## Repository structure

- `apps/` — iOS application.
- `services/` — future backend services.
- `docs/` — product, architecture, quality, AI workflow, and decisions.
- `.agents/` — project-specific Antigravity agents and skills.
- `tests/` — fixtures and evaluation datasets.

## Development principle

AI agents accelerate implementation; they do not replace engineering judgment. Every completed feature must satisfy its acceptance criteria, have appropriate tests, and remain understandable by the project owner.

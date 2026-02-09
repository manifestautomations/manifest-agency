# Contributing to Manifest Automations

Welcome to the team! This document outlines how we work, how we ship, and how we keep our sanity.

## The Core Rule: "Earned Autonomy"
We operate on a trust-based system.
- **Level 0 (New)**: Read-only. Submit PRs. Ask for review.
- **Level 1 (Contributor)**: Can merge non-critical changes.
- **Level 2 (Maintainer)**: Can merge to `main`.
- **Level 3 (Architect)**: Can change core infrastructure.

## Workflow

1.  **Pick a Task**: Check `.planning/active-projects.md` or GitHub Issues.
2.  **Branch**: `type/description` (e.g., `feat/add-login`, `fix/broken-link`).
3.  **Commit**: Conventional Commits (e.g., `feat: add login page`).
4.  **PR**: Open a PR against `main`. Link the issue.
5.  **Review**: Wait for CI/CD checks (Lobster workflows) and human review.

## Code Style

- **TypeScript**: Strict mode always.
- **Formatting**: Prettier + ESLint.
- **Comments**: Explain *why*, not *what*.

## Definition of Done

- [ ] Code builds without errors.
- [ ] Tests pass (if applicable).
- [ ] Documentation updated (README, BRIEF.md).
- [ ] Self-review performed.

## Tools We Use

- **Lobster**: For automated workflows (`workflows/*.json`).
- **Supabase**: For backend/db.
- **Expo**: For mobile.

---
*Build cool stuff. Don't break the build.*

# [Project Name] - Project Guidelines

> Inherits from: `../../CLAUDE.md` (agency-level conventions)

## Project Overview

**Purpose**: [Describe what this project does and why it exists]

**Scope**: [Define boundaries - what's in and out of scope]

**Success Criteria**: [How do we know when this project is done?]

---

## Project-Specific Conventions

### Technology Stack
- **Language**: [Primary language(s)]
- **Framework**: [Framework(s) in use]
- **Database**: [Database technology, if any]
- **Infrastructure**: [Hosting, deployment target]

### Code Style
- Follow [style guide reference]
- Naming conventions: [project-specific patterns]
- File organization: [describe structure]

### Testing Requirements
- Unit test coverage target: [percentage]
- Integration tests required for: [list areas]
- E2E tests: [yes/no, scope]

---

## Workflow Overrides

### Trust Level Adjustments
*Any project-specific trust level modifications*

| Action | Required Level | Notes |
|--------|---------------|-------|
| Deploy to staging | 2 | Standard |
| Deploy to production | 4 | Full autonomy required |
| Database migrations | 3 | Requires checkpoint |

### Custom Checkpoints
*Define project-specific review points*

- [ ] Before database schema changes
- [ ] Before API contract modifications
- [ ] Before dependency upgrades

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `.planning/BRIEF.md` | Original requirements |
| `.planning/ROADMAP.md` | Phase breakdown |
| `src/` | Source code |
| `tests/` | Test suites |
| `docs/` | Documentation |

---

## Domain Knowledge

### Key Concepts
- **[Term 1]**: Definition
- **[Term 2]**: Definition

### Business Rules
1. [Important rule or constraint]
2. [Another rule]

### External Dependencies
- **[Service Name]**: [Purpose, API docs link]
- **[Package Name]**: [Why it's used]

---

## Team & Contacts

| Role | Name/Agent | Contact |
|------|------------|---------|
| Product Owner | [Name] | [Contact] |
| Technical Lead | [Name] | [Contact] |
| Primary Agent | [Agent type] | N/A |

---

## Decision Log

| Date | Decision | Rationale | Made By |
|------|----------|-----------|---------|
| [Date] | [What was decided] | [Why] | [Who] |

---

## Notes

*Additional project-specific notes, links, or context*

---

*Created: [Date]*
*Last updated: [Date]*

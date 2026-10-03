---
phase: 02-github-coordination
plan: 04
subsystem: infra
tags: [gh-cli, bash, pr-automation, project-queries, graphql-api]

# Dependency graph
requires:
  - phase: 02-02
    provides: Field ID caching and project bootstrap infrastructure
  - phase: 02-01
    provides: GitHub templates (pr-body.md)
provides:
  - PR creation script with agent metadata and issue linking
  - Project query script with multi-filter capabilities
  - Generic field update script for any project field
affects: [02-05, agent-workflows, orchestration, pr-management]

# Tech tracking
tech-stack:
  added: [gh pr create, gh project item-list, GraphQL mutations]
  patterns: [template-based PR bodies, jq filtering pipelines, generic field updates]

key-files:
  created:
    - scripts/github/pr-create.sh
    - scripts/github/project-query.sh
    - scripts/github/project-update-field.sh
  modified: []

key-decisions:
  - "PR metadata captured in structured table (agent, duration, model, trust level)"
  - "Query script supports multiple output formats (json, table, list) for different consumers"
  - "Generic update script handles both text and single select fields via type detection"

patterns-established:
  - "Template loading and placeholder replacement pattern for PR bodies"
  - "jq filtering pipeline for complex project queries"
  - "Field type detection from cache for correct GraphQL mutation format"

# Metrics
duration: 4min
completed: 2026-01-27
---

# Phase 2 Plan 4: PR Management and Project Queries Summary

**Three composable scripts enable agents to complete work (PRs with metadata), discover available tasks (project queries), and update fields generically**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-27T10:04:42Z
- **Completed:** 2026-01-27T10:08:45Z (estimated)
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Created PR creation script with structured agent metadata table and issue linking
- Built flexible project query script with 5+ filter options and 3 output formats
- Implemented generic field update script supporting both text and single select field types
- All scripts use cached field definitions from 02-02 bootstrap for efficiency

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PR creation script with agent metadata** - `12b4a57` (feat)
2. **Task 2: Create project query script** - `8c1f9dd` (feat)
3. **Task 3: Create generic field update script** - `3ed5c1f` (feat)

**Plan metadata:** Not yet created (this is SUMMARY.md)

## Files Created/Modified
- `scripts/github/pr-create.sh` - Creates PRs with agent metadata (duration, model, trust level), links to issues, uses template from templates/github/pr-body.md
- `scripts/github/project-query.sh` - Queries project items with filters (status, unclaimed, agent-type, phase, priority), outputs json/table/list formats
- `scripts/github/project-update-field.sh` - Updates any project field via GraphQL, handles text and single select types, uses cached field IDs

## Decisions Made

**1. PR metadata in structured table format**
- Rationale: Machine-parseable but also human-readable in GitHub UI
- Fields: Agent name, issue number, worktree, duration, model, trust level, commit count
- Impact: Enables PR analysis and agent performance tracking

**2. Multiple query output formats**
- Rationale: Different consumers need different formats (scripts need json, humans need table, simple lists for quick checks)
- Formats: json (machine), table (human), list (simple)
- Impact: Single script serves multiple use cases

**3. Generic field update script vs specialized scripts**
- Rationale: Provides flexibility for any field update, can be wrapped by specialized scripts later
- Approach: Type detection from cache + correct GraphQL mutation format per type
- Impact: Swiss army knife approach vs many single-purpose scripts

## Deviations from Plan

None - plan executed exactly as written.

All three scripts implemented per specification with required features:
- PR script: metadata table, template loading, issue linking, agent tracking
- Query script: multiple filters, jq pipeline, format options
- Update script: text and single select support, cache loading, GraphQL mutations

## Issues Encountered

None - script creation was straightforward with clear specifications.

## User Setup Required

None - no external service configuration required. Scripts use gh CLI which was already configured in prerequisites.

## Next Phase Readiness

**Ready for next phase (02-05: Issue lifecycle and claiming):**
- PR creation workflow complete with metadata tracking
- Project query enables agents to discover Ready issues
- Generic field update provides building blocks for status transitions
- All scripts validated with bash syntax checks

**Foundation complete for:**
- Issue claiming workflow (query unclaimed → update Claimed By field → update Status)
- PR-based completion flow (agent finishes work → creates PR → closes issue)
- Agent work discovery (query by agent type, phase, priority)

**No blockers:**
- Scripts are composable and can be called from orchestrator
- Error handling covers common failure cases
- Help documentation available in each script

---
*Phase: 02-github-coordination*
*Completed: 2026-01-27*

---
phase: 02-github-coordination
plan: 03
subsystem: infra
tags: [github-issues, gh-cli, bash, coordination-layer, issue-lifecycle]

# Dependency graph
requires:
  - phase: 02-02
    provides: Project bootstrap with cached field IDs for GraphQL mutations
provides:
  - Issue creation script with labels and project linking
  - Issue claiming script with field updates and comment
  - Status update script for workflow transitions
  - Structured comment script with progress metadata
affects: [03-orchestrator, agent-coordination, issue-lifecycle, progress-tracking]

# Tech tracking
tech-stack:
  added: [gh issue commands, GraphQL updateProjectV2ItemFieldValue mutations]
  patterns: [positional arguments for issue numbers, cached field ID extraction with jq, HTML comment metadata for machine parsing]

key-files:
  created:
    - scripts/github/issue-create.sh
    - scripts/github/issue-claim.sh
    - scripts/github/issue-update-status.sh
    - scripts/github/issue-comment.sh
  modified: []

key-decisions:
  - "Issue number as positional argument (not --issue flag) for natural CLI usage"
  - "Progress metadata embedded in HTML comments for machine parsing without visual clutter"
  - "Blocker comments automatically add 'blocked' label for visibility"

patterns-established:
  - "Positional issue number pattern: ./script.sh <number> --option value"
  - "Cache file validation pattern: check existence before jq extraction"
  - "GraphQL project item lookup pattern: query repository issue projectItems"
  - "Structured metadata pattern: <!-- agent:progress ... --> in comments"

# Metrics
duration: 5min
completed: 2026-01-27
---

# Phase 2 Plan 3: Issue Lifecycle Management Summary

**Complete issue lifecycle automation via four shell scripts: create (with labels and project linking), claim (with field updates), status updates (workflow transitions), and structured commenting (with progress metadata)**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-27T10:03:53Z
- **Completed:** 2026-01-27T14:58:32Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Created issue creation script that accepts title/body/template, builds label string from flags, creates issue, and links to project
- Built issue claiming script that loads cached field IDs, gets project item ID, updates Claimed By and Status fields via GraphQL, and posts claim comment
- Implemented status update script for workflow state transitions (Backlog → Ready → Claimed → In Progress → In Review → Done)
- Developed structured comment script that posts human-readable messages with optional machine-parseable progress metadata in HTML comments

## Task Commits

Each task was committed atomically:

1. **Task 1: Create issue creation script** - `3d6cf99` (feat)
2. **Task 2: Create issue claiming and status update scripts** - `17ae3c8` (feat)
3. **Task 3: Create structured comment script** - `8f638a1` (feat)

**Plan metadata:** Not yet created (this is SUMMARY.md)

## Files Created/Modified
- `scripts/github/issue-create.sh` - Creates issues with labels (priority, complexity, agent-type, phase, custom) and links to project board
- `scripts/github/issue-claim.sh` - Claims issue by setting Claimed By field (text) and Status to Claimed (single select) via GraphQL mutations
- `scripts/github/issue-update-status.sh` - Updates Status field to any valid workflow state with validation
- `scripts/github/issue-comment.sh` - Posts comments with optional progress metadata (agent, status, progress %, elapsed, current task, blockers)

## Decisions Made

**1. Issue number as positional argument (not --issue flag)**
- Rationale: Natural CLI pattern matching gh CLI conventions (e.g., `gh issue view 42`)
- Pattern: `./script.sh <issue-number> --option value`
- Impact: More ergonomic for agent scripts and manual testing

**2. Progress metadata embedded in HTML comments**
- Rationale: Machine-parseable without cluttering human-readable output
- Format: `<!-- agent:progress\nagent: name\nstatus: implementing\n... -->`
- Impact: Future tooling can extract metrics without affecting issue comment readability

**3. Blocker comments automatically add 'blocked' label**
- Rationale: Visual indicator in issue lists that work is blocked
- Trigger: `--blockers "description"` parameter (not default "None")
- Impact: Blocked issues surface immediately in filtered views

## Deviations from Plan

None - plan executed exactly as written.

All scripts follow the specified patterns:
- Task 1: issue-create.sh accepts all required parameters and creates labeled, project-linked issues
- Task 2: issue-claim.sh and issue-update-status.sh use GraphQL updateProjectV2ItemFieldValue mutations with cached field IDs
- Task 3: issue-comment.sh posts structured comments with optional metadata and handles blocker labeling

## Issues Encountered

None - scripts implemented as specified with all verifications passing.

## User Setup Required

None - no external service configuration required.

Scripts require:
- `gh` CLI authenticated (same as project-bootstrap.sh)
- `.cache/github/project-fields.json` exists (created by project-bootstrap.sh)
- Issues must be added to project before claiming/status updates

## Next Phase Readiness

**Ready for orchestrator integration (Phase 3):**
- Complete issue lifecycle coverage: create → claim → update → comment
- Scripts are composable with clear input/output contracts
- Machine-parseable metadata in comments enables progress tracking
- Error handling for "issue not in project" provides clear remediation

**Foundation complete for:**
- Agent work claiming workflow (query Ready issues, claim via script)
- Progress reporting automation (comment with status/progress updates)
- Status workflow enforcement (valid state transitions only)
- Blocker escalation (automatic label addition for visibility)

**Patterns established for 02-04 (PR and query scripts):**
- Positional arguments for natural CLI usage
- Cached field ID extraction with jq
- GraphQL mutation pattern for project item updates
- Structured metadata in comments/descriptions

---
*Phase: 02-github-coordination*
*Completed: 2026-01-27*

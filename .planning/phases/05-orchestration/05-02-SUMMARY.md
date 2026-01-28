---
phase: 05-orchestration
plan: 02
subsystem: orchestration
tags: [gemini, decomposition, vertical-slicing, dependency-graph, tsort, github-cli]

# Dependency graph
requires:
  - phase: 05-01
    provides: Gemini orchestrator skill skeleton
provides:
  - decomposition helper with vertical slicing prompts
  - dependency graph builder with tsort cycle detection
  - issue-ready detection for parallel dispatch
  - cascade failure detection
affects: [05-03, 05-04, 05-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Vertical slice decomposition (end-to-end features, not horizontal layers)"
    - "tsort for topological sort and cycle detection"
    - "'Blocked by #N' format for issue dependencies"
    - "jq scan() for pattern extraction from issue bodies"

key-files:
  created:
    - scripts/orchestrator/decompose.sh
    - scripts/orchestrator/graph.sh
  modified: []

key-decisions:
  - "Vertical slice prompts include Foundation+Features pattern guidance"
  - "Dependency format 'Blocked by #N' matches CONTEXT.md convention"
  - "tsort exit code for cycle detection (POSIX standard)"
  - "jq scan() for case-insensitive pattern extraction"

patterns-established:
  - "Orchestrator helpers in scripts/orchestrator/ directory"
  - "CLI interface with direct invocation or source-and-call pattern"

# Metrics
duration: 4min
completed: 2026-01-28
---

# Phase 5 Plan 2: Orchestrator Helpers Summary

**Decomposition and dependency graph helpers for Gemini orchestrator with vertical slicing prompts and tsort-based cycle detection**

## Performance

- **Duration:** 4 min 23 sec
- **Started:** 2026-01-28T13:34:11Z
- **Completed:** 2026-01-28T13:38:34Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Decomposition helper generates Gemini prompts with vertical slice guidance (end-to-end features, not horizontal layers)
- Dependency graph builder extracts "Blocked by #N" patterns from issue bodies via GitHub CLI
- Cycle detection using tsort (POSIX standard) with clear error messages
- Ready issue detection for parallel dispatch (finds issues with no unresolved blockers)
- Cascade detection identifies all dependents when an issue fails

## Task Commits

Each task was committed atomically:

1. **Task 1: Create decomposition helper script** - `4843d5a` (feat)
2. **Task 2: Create dependency graph builder** - `c81a02c` (feat)

## Files Created/Modified

- `scripts/orchestrator/decompose.sh` - Generates decomposition prompts for Gemini with vertical slicing guidance, validates JSON output, formats for issue creation
- `scripts/orchestrator/graph.sh` - Builds dependency graph from GitHub issues, provides topological sort via tsort, detects cycles and cascades

## Decisions Made

- **Vertical slice guidance in prompts:** Explicitly includes "Foundation + Features" pattern and warns against horizontal decomposition
- **Case-insensitive pattern matching:** jq scan() uses `[Bb]locked by #` to handle both cases
- **Empty graph handling:** Returns gracefully when no dependencies exist (all issues dispatchable)
- **Transitive cascade detection:** detect_cascade() follows dependency chain recursively

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Decomposition helper ready for orchestrator skill to use for CEO intent parsing
- Graph builder ready for dispatch script to determine execution order
- Ready issues function supports parallel dispatch (Plan 05-03)
- Cascade detection supports failure handling (Plan 05-05)

---
*Phase: 05-orchestration*
*Completed: 2026-01-28*

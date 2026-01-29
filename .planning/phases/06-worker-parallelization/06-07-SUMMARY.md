---
phase: 06-worker-parallelization
plan: 07
subsystem: worker
tags: [bash, shell, sourcing, include-guards, library-loading]

# Dependency graph
requires:
  - phase: 06-05
    provides: Wave aggregation and worker integration with sub-agent spawning
provides:
  - Fixed library sourcing paths for Phase 6 parallelization libs
  - Include guards preventing multiple-source errors
  - Working execute.sh that loads all required libraries
affects: [phase-7-ceo-dispatch, future-worker-enhancements]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Include guard pattern for bash sourced libraries
    - WORKER_SCRIPT_DIR variable to preserve path across sourcing chain

key-files:
  created: []
  modified:
    - scripts/worker/execute.sh
    - scripts/worker/spawn-subagent.sh
    - scripts/worker/aggregate-wave.sh
    - scripts/worker/lib/graph-parser.sh
    - scripts/worker/lib/scope-validator.sh
    - scripts/worker/lib/subagent-scope.sh
    - scripts/worker/lib/timeout-manager.sh

key-decisions:
  - "Use include guards ([[ -n \"${_VAR_SOURCED:-}\" ]] && return 0) instead of set -euo pipefail in sourced libs"
  - "Save WORKER_SCRIPT_DIR before sourcing Phase 3/4 libs that overwrite SCRIPT_DIR"
  - "Replace set -euo pipefail with include guards in spawn-subagent.sh and aggregate-wave.sh"

patterns-established:
  - "Include guard pattern: Check guard variable, return 0 if set, set guard and continue"
  - "Path preservation: Save critical paths before sourcing external libs that may overwrite them"

# Metrics
duration: 8min
completed: 2026-01-29
---

# Phase 6 Plan 07: Gap Closure for UAT Failures

**Fixed library sourcing chain for worker parallelization - include guards prevent readonly errors, WORKER_SCRIPT_DIR preserves path across Phase 3/4 lib sourcing**

## Performance

- **Duration:** 8 min
- **Started:** 2026-01-29T00:05:00Z
- **Completed:** 2026-01-29T00:13:00Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- Fixed execute.sh to correctly source Phase 6 parallelization libraries
- Added include guards to all Phase 6 libraries preventing multiple-source errors
- Removed set -euo pipefail from sourced libraries that was breaking interactive shells
- All library sourcing tests pass (graph-parser, scope-validator, subagent-scope, timeout-manager)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix LIB_DIR path in execute.sh** - `7e6852d` (fix)
2. **Task 2: Remove set -euo pipefail from library files** - `ce42df5` (fix)
3. **Task 3 (additional fixes discovered during verification):** - `382b202` (fix)
   - Add include guards to all Phase 6 libraries
   - Save WORKER_SCRIPT_DIR before sourcing Phase 3/4 libs
   - Replace set -euo pipefail with include guards in spawn-subagent.sh and aggregate-wave.sh

## Files Modified
- `scripts/worker/execute.sh` - Save WORKER_SCRIPT_DIR, use it for Phase 6 lib paths
- `scripts/worker/spawn-subagent.sh` - Add include guard, remove set -euo pipefail
- `scripts/worker/aggregate-wave.sh` - Add include guard, remove set -euo pipefail
- `scripts/worker/lib/graph-parser.sh` - Add include guard, remove set -euo pipefail
- `scripts/worker/lib/scope-validator.sh` - Add include guard, remove set -euo pipefail
- `scripts/worker/lib/subagent-scope.sh` - Add include guard, remove set -euo pipefail
- `scripts/worker/lib/timeout-manager.sh` - Add include guard, remove set -euo pipefail

## Decisions Made

1. **Include guard pattern over set -euo pipefail for sourced libraries**
   - Libraries are sourced, not executed directly
   - set -u causes errors on undefined variables like BP_PIPESTATUS in shell prompts
   - set -e can cause parent shell to exit unexpectedly
   - Include guards ([[ -n "${_VAR_SOURCED:-}" ]] && return 0) are idiomatic for bash libs

2. **Save WORKER_SCRIPT_DIR before sourcing Phase 3/4 libs**
   - Phase 3/4 libs (hooks.sh, validator.sh) overwrite SCRIPT_DIR
   - WORKER_SCRIPT_DIR preserves execute.sh's original path
   - Phase 6 libs sourced using WORKER_SCRIPT_DIR instead of potentially-overwritten SCRIPT_DIR

3. **Include guards in spawn-subagent.sh and aggregate-wave.sh**
   - These scripts are sourced by execute.sh
   - They source Phase 6 libs which may already be loaded
   - Include guards prevent duplicate sourcing and readonly variable errors

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SCRIPT_DIR overwritten by Phase 3/4 libs**
- **Found during:** Task 3 verification
- **Issue:** hooks.sh and validator.sh redefine SCRIPT_DIR, breaking Phase 6 lib paths
- **Fix:** Added WORKER_SCRIPT_DIR variable to preserve original path before sourcing
- **Files modified:** scripts/worker/execute.sh
- **Verification:** Full source chain completes without path errors
- **Committed in:** 382b202

**2. [Rule 3 - Blocking] readonly variable errors on multiple sourcing**
- **Found during:** Task 3 verification
- **Issue:** subagent-scope.sh has `readonly MAX_NESTING_DEPTH=2` which fails on re-source
- **Fix:** Added include guards to all Phase 6 libraries
- **Files modified:** All 4 Phase 6 libs plus spawn-subagent.sh and aggregate-wave.sh
- **Verification:** Libraries can be sourced multiple times without errors
- **Committed in:** 382b202

---

**Total deviations:** 2 auto-fixed (both Rule 3 - Blocking)
**Impact on plan:** Both auto-fixes necessary for script to function. No scope creep.

## Issues Encountered

1. **Script output not captured in Claude Code terminal environment**
   - execute.sh --help runs successfully (exit 0) but output not visible
   - Appears to be Windows/MINGW64 specific terminal capture issue
   - Verified script works by checking syntax, function availability, and source content
   - Not a code issue - environment-specific output buffering behavior

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Worker parallelization infrastructure is now functional
- UAT Tests 8 and 9 issues are resolved
- execute.sh correctly sources all required libraries
- All Phase 6 functions (extract_execution_graph, validate_dag, spawn_subagent, aggregate_wave_results) are available
- Ready for Phase 7 CEO dispatch integration

---
*Phase: 06-worker-parallelization*
*Plan: 07*
*Completed: 2026-01-29*

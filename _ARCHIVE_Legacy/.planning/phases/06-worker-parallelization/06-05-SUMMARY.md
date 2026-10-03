---
phase: 06-worker-parallelization
plan: 05
subsystem: worker
tags: [bash, parallel-execution, git, jq, sub-agents, wave-aggregation]

# Dependency graph
requires:
  - phase: 06-01
    provides: Graph parser with YAML extraction and DAG validation
  - phase: 06-02
    provides: Sub-agent scope derivation and constraint validation
  - phase: 06-03
    provides: Timeout management with soft-then-hard protocol
  - phase: 06-04
    provides: Scope validator and spawner with PID tracking
provides:
  - Wave result aggregation with verification pipeline
  - Unified wave commits per CONTEXT.md format
  - Rollback and salvage operations for failed waves
  - Worker entry point with automatic parallelization detection
  - Backward compatible serial execution fallback
affects: [07-integration-testing, orchestrator, worker-execution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave aggregation with structural and syntactic verification"
    - "Let-finish with salvage pattern for partial success recovery"
    - "Conditional execution based on execution graph presence"
    - "Unified commit messages with per-agent summaries"

key-files:
  created:
    - scripts/worker/aggregate-wave.sh
  modified:
    - scripts/worker/execute.sh

key-decisions:
  - "Wave commits include all sub-agent work in single atomic commit"
  - "Verification pipeline: structural (file exists) then syntactic (parses)"
  - "Rollback unstages and restores without history pollution"
  - "Serial execution is default when no execution graph present"
  - "PLAN.md location: .worker/plans/issue-N-PLAN.md (future integration point)"

patterns-established:
  - "aggregate_wave_results: collect from completed sub-agents with verification"
  - "create_wave_commit: unified commit with per-agent summaries and metadata"
  - "handle_wave_failure: let-finish pattern with salvage decision logic"
  - "execute_with_subagents: wave-based parallel execution with DAG traversal"
  - "Conditional execution in execute.sh: serial (existing) or parallel (sub-agents)"

# Metrics
duration: 4min
completed: 2026-01-29
---

# Phase 6 Plan 5: Wave Aggregation and Worker Integration Summary

**Worker automatically detects execution graphs and spawns sub-agents in parallel waves, aggregating results into unified commits with rollback and salvage support**

## Performance

- **Duration:** 3m 38s
- **Started:** 2026-01-29T03:18:21Z
- **Completed:** 2026-01-29T03:21:59Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Wave aggregation with structural and syntactic verification pipeline
- Unified wave commits containing all sub-agent work with proper metadata
- Rollback mechanism that unstages and restores without history pollution
- Worker execute.sh integration with automatic parallelization detection
- Backward compatible serial execution when no execution graph present

## Task Commits

Each task was committed atomically:

1. **Task 1: Create wave aggregation script** - `1093e86` (feat)
2. **Task 2: Integrate sub-agent spawning into execute.sh** - `256e62b` (feat)

## Files Created/Modified

### Created
- `scripts/worker/aggregate-wave.sh` - Wave result aggregation and commit management
  - `aggregate_wave_results()`: Collects results from completed sub-agents in wave
  - `verify_wave_outputs()`: Structural (files exist) and syntactic (code parses) verification
  - `create_wave_commit()`: Unified commit with per-agent summaries per CONTEXT.md format
  - `rollback_wave()`: Unstages and restores to pre-wave state without history pollution
  - `handle_wave_failure()`: Let-finish pattern with salvage decision logic

### Modified
- `scripts/worker/execute.sh` - Worker entry point with sub-agent support
  - Sources graph-parser.sh, spawn-subagent.sh, aggregate-wave.sh libraries
  - Added `--serial` flag for forced serial execution
  - Added `execute_with_subagents()` function for wave-based parallel execution
  - Detects execution graphs via `extract_execution_graph` at lines 350-389
  - Conditional execution: serial (existing Claude call) or parallel (sub-agents)
  - Backward compatible - defaults to serial when no graph present

## Decisions Made

**Wave commit format:**
- Follows CONTEXT.md specification with scope, wave number, per-agent summaries
- Includes phase, wave, duration, and worker_id metadata
- Uses heredoc for multi-line commit message construction

**Verification pipeline:**
- Layer 1: Structural - all expected outputs present
- Layer 2: Syntactic - code parses (bash -n, node --check, tsc, python -m py_compile, jq, yq)
- Skips unknown file types (non-blocking)
- Returns 1 if any verification fails

**Salvage logic:**
- Let running agents finish (no cancellation)
- Assess if completed work is independent and salvageable
- If salvageable: aggregate partial, report failed agents for retry
- If not salvageable: rollback entire wave
- Decision based on verification success and completion count

**Execution mode detection:**
- Checks for `.worker/plans/issue-N-PLAN.md` file
- Calls `extract_execution_graph` to detect YAML block
- Defaults to serial if no file or no graph
- `--serial` flag forces serial execution regardless

**Integration location:**
- Lines 350-389 in execute.sh (Claude invocation section) per plan
- Wraps existing Claude call in conditional: serial or parallel
- Preserves all existing serial execution behavior

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation followed established patterns from previous plans.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Phase 6 Complete:**
- All 5 plans executed successfully
- Worker parallelization foundation complete:
  - Graph parser (06-01)
  - Sub-agent scoping (06-02)
  - Timeout management (06-03)
  - Scope validator and spawner (06-04)
  - Wave aggregation and integration (06-05)

**Ready for Phase 7 (Integration Testing):**
- Worker can now execute tasks in parallel when execution graphs present
- Aggregates results into unified commits
- Handles failures gracefully with salvage
- Falls back to serial execution when appropriate

**Integration points for Phase 7:**
- `.worker/plans/issue-N-PLAN.md` file generation (currently stubbed)
- Trust level approval gates (referenced but not enforced)
- Execution graph creation from issue acceptance criteria
- End-to-end testing with real GitHub issues

**No blockers or concerns.**

---
*Phase: 06-worker-parallelization*
*Completed: 2026-01-29*

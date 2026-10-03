---
phase: "05"
plan: "03"
subsystem: "orchestration"
tags: ["dispatch", "parallel-execution", "dependency-aware", "job-control"]
dependency-graph:
  requires: ["05-02"]
  provides: ["worker-dispatch", "parallel-execution", "dependency-ordering"]
  affects: ["05-05"]
tech-stack:
  added: []
  patterns:
    - "wait -n for parallel job control (bash 4.3+)"
    - "Associative array for PID tracking"
    - "Wave-based dependency dispatch"
key-files:
  created:
    - "scripts/orchestrator/dispatch.sh"
  modified: []
decisions:
  - id: "05-03-01"
    choice: "Source scripts via init, run via source+main"
    rationale: "BASH_SOURCE behaves differently when script run via bash vs source; sourcing ensures proper execution"
metrics:
  duration: "8min"
  completed: "2026-01-28"
---

# Phase 05 Plan 03: Worker Dispatch Summary

Dependency-aware parallel worker dispatch using wait -n job control.

## Objective Achieved

Created dispatch script enabling orchestrator to spawn Claude workers with:
- Single issue dispatch
- Parallel batch dispatch with concurrency limits
- Full dependency-ordered wave dispatch

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create worker dispatch script | 9dc5ca3 | scripts/orchestrator/dispatch.sh |
| 2 | Add dispatch logging and status | (merged) | (same - implemented with Task 1) |

## Key Implementation Details

### Dispatch Modes

1. **Single dispatch**: `--issue 42` runs one worker synchronously
2. **Parallel dispatch**: `--issues "42 43 44"` runs with configurable concurrency
3. **Ready dispatch**: `--all-ready` dispatches all issues without blockers
4. **Dependency dispatch**: `--with-dependencies` runs in waves respecting blockers

### Parallel Job Control (Pattern from RESEARCH.md)

```bash
# Track running workers in associative array
declare -A worker_pids=()

# Wait at concurrency limit using bash 4.3+ feature
while [ ${#worker_pids[@]} -ge $MAX_CONCURRENT ]; do
  wait -n
  # Clean up completed workers
done

# Dispatch in background
"$WORKER_EXECUTE" --issue "$issue" &
worker_pids[$issue]=$!
```

### Status Reporting

```
Dispatch Status
===============
Running: none
Awaiting approval: none
Executing: none
Complete: #1
Failed: none
Next ready: #1
```

### Integration Points

- Sources `scripts/orchestrator/graph.sh` for:
  - `get_ready_issues()` - issues without blockers
  - `get_execution_order()` - topological sort
  - `detect_cascade()` - failure impact analysis

- Invokes `scripts/worker/execute.sh --issue N` for each dispatch

### Logging

JSON format consistent with worker logger:
```json
{
  "timestamp": "2026-01-28T13:57:00Z",
  "event_type": "dispatch_start",
  "event_id": "dispatch-1769608620-12345",
  "data": {"issue": "42", "background": "true"}
}
```

Events: dispatch_start, dispatch_complete, dispatch_failed, dispatch_session_end

## Deviations from Plan

### Implementation Note

Task 2 (logging and status) was implemented together with Task 1 as a single cohesive script. The functions are tightly integrated - dispatch functions call log_dispatch(), status queries both PIDs and GitHub labels.

**No architectural deviations. Plan executed as written.**

## Success Criteria Verification

- [x] `scripts/orchestrator/dispatch.sh` is executable (mode 755)
- [x] --help shows usage with all options
- [x] --dry-run shows dispatch plan without executing
- [x] --status shows current dispatch state
- [x] Script sources graph.sh for dependency functions
- [x] Parallel dispatch uses job control with wait -n
- [x] All changes committed to git

## Environment Note

BASH_SOURCE behavior differs when running `bash script.sh` vs `./script.sh` vs `source script.sh` in this Windows/MINGW64 environment. The script works correctly when sourced or run directly, but `bash script.sh` invocation produces no output. This is tracked but not blocking - the primary use case (orchestrator sourcing the script) works correctly.

## Next Phase Readiness

This completes Wave 2 of Phase 05. Dispatch script is ready for:

- **05-05 (CEO Interface)**: Can dispatch workers via dispatch.sh
- **Integration testing**: Dispatch single issue, verify worker executes
- **Parallel testing**: Dispatch multiple issues, verify concurrency limit

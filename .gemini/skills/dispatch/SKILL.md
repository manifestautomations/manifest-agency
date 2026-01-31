---
name: dispatch
description: Explicitly dispatch work to Claude workers for specified issues or natural language intent
---

# Worker Dispatch Skill

## Goal

Dispatch work to Claude workers based on CEO intent, handling workspace resolution, dependency graphs, and approval gates.

## Instructions

### Issue-Based Dispatch

If CEO specifies issue number(s):

```bash
# Single issue
scripts/orchestrator/dispatch.sh --issue 42

# Multiple issues in parallel
scripts/orchestrator/dispatch.sh --issues "42 43 44" --max-concurrent 3

# All ready issues (no blockers)
scripts/orchestrator/dispatch.sh --all-ready

# Full dependency-aware dispatch
scripts/orchestrator/dispatch.sh --with-dependencies
```

### Workspace-Specific Dispatch

If CEO specifies workspace:

1. **Resolve workspace:**
   ```bash
   WORKSPACE_PATH=$(scripts/workspace/workspace-resolve.sh "Project X")
   ```

2. **Check health:**
   ```bash
   scripts/workspace/workspace-health.sh "$WORKSPACE_PATH"
   ```
   - GREEN: Proceed
   - YELLOW: Warn CEO, allow proceed
   - RED: Block, surface issues

3. **Validate trust ceiling:**
   ```bash
   scripts/dispatch/trust-validation.sh "$WORKSPACE_PATH"
   ```
   Exit code 0 = within ceiling, 1 = exceeds ceiling

4. **Check approval gate:**
   ```bash
   scripts/dispatch/approval-gate.sh "$WORKSPACE_PATH"
   ```
   - Exit code 0: Approved or not needed, proceed
   - Exit code 1: Needs approval, EXIT and surface to CEO
   - Exit code 2: Denied

5. **Dispatch in workspace context:**
   ```bash
   cd "$WORKSPACE_PATH"
   scripts/orchestrator/dispatch.sh --issue N
   ```

### Natural Language Dispatch

If CEO provides intent without issue number:

1. **Decompose into tasks:**
   ```bash
   scripts/orchestrator/decompose.sh prompt "Build dark mode for dashboard"
   ```

2. **Present decomposition for confirmation:**
   ```
   I'll decompose this into 3 issues:

   1. Foundation - Theme system (CSS vars, toggle)
      Size: M, Dependencies: None

   2. Dark mode for dashboard
      Size: S, Blocked by: #1

   3. Dark mode for settings
      Size: S, Blocked by: #1

   Ready to create these?
   ```

3. **Wait for CEO confirmation**

4. **Create GitHub issues:**
   ```bash
   scripts/orchestrator/decompose.sh format "$JSON" > issues.json
   # For each issue:
   gh issue create --title "TITLE" --body "BODY"
   ```

5. **Dispatch ready workers:**
   ```bash
   scripts/orchestrator/dispatch.sh --with-dependencies
   ```

## Cross-Workspace Flow

When dispatching to workspace outside current context:

1. Resolve → Health → Trust → Approval → Dispatch
2. If approval gate returns exit code 1:
   - STOP (do not proceed)
   - Surface approval request to CEO
   - Wait for CEO to run `/approve <ID>`
   - After approval, CEO re-runs dispatch command

This is the **exit-and-resume pattern** from Phase 11.

## Dispatch Modes

**Single:**
- Dispatch one issue, ignore dependencies
- Use when CEO explicitly targets specific issue
- Example: "dispatch #42"

**Parallel:**
- Dispatch multiple ready issues concurrently
- Respects max-concurrent limit (default: 3)
- Example: "dispatch #42, #43, #44"

**Dependency-aware:**
- Build dependency graph via graph.sh
- Dispatch in topological order
- Wait for blockers before dispatching dependents
- Example: "dispatch with dependencies"

## Error Handling

**Transient failures (auto-retry):**
- Lock timeout → Retry with --force
- Rate limit → Backoff and retry
- Parse errors → Fix template and retry

**Persistent failures (escalate to CEO):**
- Execution failures
- Validation failures
- Permission errors
- Multiple consecutive failures

## Reporting

After dispatch, report:

```
Dispatched:
  - #52 Foundation - Theme system (executing, PID: 12345)

Waiting for dependencies:
  - #53 Dark mode for dashboard (blocked by #52)
  - #54 Dark mode for settings (blocked by #52)

I'll notify you when workers complete or need approval.
```

## Constraints

- Never dispatch without CEO confirmation (for natural language)
- Always resolve workspace before cross-workspace dispatch
- Respect trust ceilings (block if exceeded)
- Honor approval gates (exit-and-resume pattern)
- Log all dispatches to audit trail

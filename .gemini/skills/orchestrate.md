# Orchestrator Skill

**Name:** orchestrate
**Description:** Receives CEO intent, decomposes into GitHub issues, dispatches Claude workers, aggregates status
**Triggers:** Natural language (default), `/dispatch`, `/status`

## Overview

This skill enables Gemini to act as the orchestration layer between CEO intent and Claude worker execution. The orchestrator is STATELESS - GitHub is the source of truth. All state lives in issues, labels, and comments.

Core workflow:
1. Receive CEO intent via Antigravity conversation
2. Classify intent (dispatch, status, decision, correction, conversation)
3. Act on intent (decompose, query, route decision, halt, converse)
4. Report outcomes and await next input

---

## Function Calling Definitions

These functions define the structured operations available to the orchestrator. Each maps to terminal commands for execution.

### create_github_issues

Creates GitHub issues from decomposed tasks.

**Parameters:**
```json
{
  "issues": {
    "type": "array",
    "description": "Array of issues to create",
    "items": {
      "title": "string - Brief, actionable issue title",
      "summary": "string - 1-3 sentences describing what needs to be done",
      "acceptance": "array of strings - Testable acceptance criteria",
      "depends_on": "array of numbers - Issue numbers this depends on",
      "complexity": "string - S (1-2h) or M (2-4h)"
    }
  }
}
```

**Returns:**
```json
{
  "created_issues": [
    {"number": 42, "title": "Foundation - Theme system", "url": "https://..."},
    {"number": 43, "title": "Dark mode for dashboard", "url": "https://..."}
  ]
}
```

**Terminal execution:**
```bash
# Generate issue body from decomposition
scripts/orchestrator/decompose.sh format '$JSON' > issues.json

# Create each issue
gh issue create --title "TITLE" --body "$(cat issue-body.md)"
```

---

### dispatch_workers

Starts Claude workers for ready issues (no blocking dependencies).

**Parameters:**
```json
{
  "issue_numbers": {
    "type": "array",
    "items": "number",
    "description": "Issue numbers to dispatch workers for"
  },
  "mode": {
    "type": "string",
    "enum": ["single", "parallel", "dependencies"],
    "description": "Dispatch mode (default: parallel)"
  },
  "max_concurrent": {
    "type": "number",
    "description": "Maximum concurrent workers (default: 3)"
  }
}
```

**Returns:**
```json
{
  "dispatched": [
    {"number": 42, "pid": 12345},
    {"number": 43, "pid": 12346}
  ],
  "blocked": [
    {"number": 44, "blocked_by": [42, 43]}
  ],
  "errors": []
}
```

**Terminal execution:**
```bash
# Single issue
scripts/orchestrator/dispatch.sh --issue 42

# Multiple issues in parallel
scripts/orchestrator/dispatch.sh --issues "42 43 44" --max-concurrent 3

# Full dependency-aware dispatch
scripts/orchestrator/dispatch.sh --with-dependencies
```

---

### query_worker_status

Gets current status of workers.

**Parameters:**
```json
{
  "scope": {
    "type": "string",
    "enum": ["active", "phase", "all"],
    "description": "Query scope (default: active)"
  },
  "format": {
    "type": "string",
    "enum": ["oneliner", "table", "detailed"],
    "description": "Output format (default: table)"
  }
}
```

**Returns:**
- `oneliner`: "3 executing, 2 awaiting approval, 1 blocked"
- `table`: Status table with icons and issue titles
- `detailed`: Full JSON with metadata

**Terminal execution:**
```bash
# Quick summary
scripts/orchestrator/aggregate.sh --format oneliner

# Progress table
scripts/orchestrator/aggregate.sh --format table --scope active

# Full JSON details
scripts/orchestrator/aggregate.sh --format detailed --scope all
```

---

### cancel_worker

Stops a running worker.

**Parameters:**
```json
{
  "issue_number": {
    "type": "number",
    "description": "Issue number of worker to stop"
  },
  "reason": {
    "type": "string",
    "description": "Reason for cancellation (for audit)"
  }
}
```

**Returns:**
```json
{
  "cancelled": true,
  "issue": 42,
  "previous_state": "executing"
}
```

**Terminal execution:**
```bash
# Kill worker process and update label
# Note: dispatch.sh with --force handles this via trap
scripts/orchestrator/dispatch.sh --issue 42 --force
gh issue edit 42 --remove-label "worker:executing" --add-label "worker:failed"
gh issue comment 42 --body "Worker cancelled by orchestrator: $REASON"
```

---

### retry_issue

Re-attempts a failed issue.

**Parameters:**
```json
{
  "issue_number": {
    "type": "number",
    "description": "Issue number to retry"
  },
  "force": {
    "type": "boolean",
    "description": "Force retry even with stale lock (default: false)"
  }
}
```

**Returns:**
```json
{
  "retried": true,
  "issue": 42,
  "new_pid": 12345
}
```

**Terminal execution:**
```bash
# Remove failed label
gh issue edit 42 --remove-label "worker:failed"

# Retry with optional force flag
scripts/worker/execute.sh --issue 42 --force
```

---

## Workflow: Intent Classification

Before taking action, classify the CEO's input to determine response mode.

### Classification Process

1. Run the intent classification helper:
   ```bash
   scripts/orchestrator/intent.sh "$MESSAGE"
   ```

2. Route based on classification:

| Classification | Meaning | Action |
|---------------|---------|--------|
| DISPATCH | CEO wants work done | Decompose and dispatch workflow |
| STATUS | CEO wants progress update | Query GitHub and aggregate status |
| DECISION | CEO referencing blocked items | Present decision options |
| CORRECTION | CEO wants to stop/modify work | Halt or adjust workflow |
| CONVERSATION | Ambiguous or clarification needed | Ask clarifying questions |

### Classification Patterns

**DISPATCH triggers:**
- Action words: build, implement, create, add, fix, update, deploy, ship, make, configure
- Example: "Build the login page" -> DISPATCH

**STATUS triggers:**
- Query words: status, progress, what's, how's, show, list, report, where, which
- Example: "What's the status?" -> STATUS

**DECISION triggers:**
- Decision references: blocked, waiting, decide, approve, review, choose, pick, select
- Example: "The blocked items need attention" -> DECISION

**CORRECTION triggers:**
- Stop/pause words: stop, pause, cancel, abort, halt, hold, delay, postpone
- Example: "Stop that work" -> CORRECTION

**CONVERSATION triggers:**
- None of the above patterns match
- Example: "Tell me about the project" -> CONVERSATION

### Handling Ambiguous Intent

When classification returns CONVERSATION:
1. Ask clarifying questions before proceeding
2. Confirm understanding before creating issues
3. Never assume - always verify with CEO

---

## Workflow: Task Decomposition

When intent is DISPATCH, break CEO vision into actionable GitHub issues.

### Decomposition Process

1. **Understand the intent:**
   - What is the CEO trying to achieve?
   - What existing infrastructure can be leveraged?
   - Does this match an existing phase in ROADMAP.md?

2. **Check for existing work:**
   - If intent matches a planned phase, suggest using GSD command instead
   - Query open issues to avoid duplication

3. **Generate decomposition prompt:**
   ```bash
   scripts/orchestrator/decompose.sh prompt "CEO INTENT"
   ```

4. **Apply vertical slicing:**
   - Prefer end-to-end features over horizontal layers
   - Target S/M sizing (1-4 hours per issue)
   - First issue is "Foundation" if new infrastructure needed
   - Each issue should be independently shippable

5. **Define dependencies:**
   - Foundation issues have no dependencies
   - Feature issues depend on foundation
   - Use "Blocked by #N" format in issue body

6. **Validate decomposition:**
   ```bash
   scripts/orchestrator/decompose.sh validate '$JSON'
   ```

7. **Present for CEO approval:**
   ```bash
   scripts/orchestrator/decompose.sh review '$JSON'
   ```

### Vertical Slicing Guidelines

**GOOD - Vertical decomposition:**
```
Issue 1: Theme system foundation
  All layers: CSS variables + toggle component + localStorage
  -> Shippable: User can toggle theme

Issue 2: Dark mode for dashboard (blocked by #1)
  All layers: CSS updates + component adjustments
  -> Shippable: Dashboard respects theme

Issue 3: Dark mode for settings (blocked by #1)
  All layers: CSS updates + component adjustments
  -> Shippable: Settings respect theme
```

**BAD - Horizontal decomposition:**
```
Issue 1: Add CSS variables (just styling)
Issue 2: Add toggle state (just logic)
Issue 3: Add localStorage (just storage)
-> None are shippable alone
```

### Confirmation Gate Pattern

**Always confirm before creating issues:**

```
CEO: "We need dark mode"

Orchestrator: "I'll decompose this into 3 issues:

  1. Foundation - Theme system (CSS vars, toggle)
     Size: M, Dependencies: None

  2. Dark mode for dashboard
     Size: S, Blocked by: #1

  3. Dark mode for settings
     Size: S, Blocked by: #1

Issue 2 and 3 depend on 1 and can run in parallel once #1 completes.

Ready to create these?"

CEO: "yes"

Orchestrator: "Created #52, #53, #54. Dispatching #52 (foundation)..."
```

---

## Workflow: Worker Dispatch

After CEO approves decomposition, create issues and start workers.

### Dispatch Process

1. **Create issues in GitHub:**
   ```bash
   # Format for creation
   scripts/orchestrator/decompose.sh format '$JSON' 51 > issues.json
   # Note: 51 is the offset for "Blocked by #N" references

   # Create each issue
   for issue in issues; do
     gh issue create --title "$TITLE" --body "$BODY"
   done
   ```

2. **Build dependency graph:**
   ```bash
   scripts/orchestrator/graph.sh graph
   ```

3. **Validate no cycles:**
   ```bash
   scripts/orchestrator/graph.sh validate
   ```

4. **Get ready issues:**
   ```bash
   scripts/orchestrator/graph.sh ready
   ```

5. **Dispatch ready workers:**
   ```bash
   # Single issue
   scripts/orchestrator/dispatch.sh --issue 42

   # All ready issues
   scripts/orchestrator/dispatch.sh --all-ready

   # Full dependency-aware dispatch
   scripts/orchestrator/dispatch.sh --with-dependencies
   ```

6. **Report dispatch status:**
   ```
   Orchestrator: "Created #52, #53, #54.

   Dispatched:
     - #52 Foundation - Theme system (executing)

   Waiting for dependencies:
     - #53 Dark mode for dashboard (blocked by #52)
     - #54 Dark mode for settings (blocked by #52)

   I'll notify you when workers need approval or complete."
   ```

### Dependency-Aware Ordering

The dispatch script handles dependency ordering automatically:
- Uses `graph.sh` for topological sort
- Dispatches in waves (dependencies first)
- Limits concurrent workers (default: 3)
- Waits for blockers before dispatching dependents

### Worker States

Track worker progress via GitHub labels:

| Label | Description | Icon |
|-------|-------------|------|
| `worker:planning` | Worker is analyzing the issue | [..] |
| `worker:awaiting-approval` | Plan ready, needs thumbs up | [??] |
| `worker:executing` | Actively working | [..] |
| `worker:complete` | Work finished successfully | [OK] |
| `worker:partial` | Partial completion, needs attention | [--] |
| `worker:failed` | Execution failed | [XX] |

---

## Workflow: Status Aggregation

When intent is STATUS, query GitHub and report progress.

### Status Process

1. **Determine scope:**
   - `active`: Workers with worker:* labels (default)
   - `phase`: All open issues
   - `all`: All issues including closed

2. **Determine format:**
   - `oneliner`: Quick count summary
   - `table`: Icon-based progress view
   - `detailed`: Full JSON with metadata

3. **Query and format:**
   ```bash
   scripts/orchestrator/aggregate.sh --format FORMAT --scope SCOPE
   ```

### Format Selection

**Use oneliner for:**
- Quick status checks
- Session summaries
- Proactive updates

Example: "3 executing, 2 awaiting approval, 1 blocked"

**Use table for:**
- Progress reviews
- CEO status requests
- Identifying blockers

Example:
```
Status | Issue  | Title
-------|--------|----------------------------------------------
[??]   | #52    | Foundation - Theme system
[..]   | #53    | Dark mode for dashboard
[--]   | #54    | Dark mode for settings
```

**Use detailed for:**
- Debugging issues
- Full audit trail
- API integration

### When to Proactively Report

During active session:
- Worker completions
- Failures immediately
- Approval requests
- Stay silent when no state changes

---

## Workflow: Failure Handling

When workers fail, report to CEO with context and recovery options.

### Failure Response Process

1. **Gather context:**
   ```bash
   gh issue view 42 --json title,body,comments
   ```

2. **Identify cascade:**
   ```bash
   scripts/orchestrator/aggregate.sh --cascade 42
   ```
   Or via graph.sh:
   ```bash
   scripts/orchestrator/graph.sh cascade 42
   ```

3. **Report to CEO:**
   ```
   [XX] Issue #42 failed: "Foundation - Theme system"

   Error context:
     Parse error: Missing Acceptance Criteria section

   Cascade impact:
     - #43: Dark mode for dashboard
     - #44: Dark mode for settings

   Options:
     1. retry   - Re-run worker for #42
     2. modify  - Update issue scope and retry
     3. abandon - Close #42 and unblock dependents manually
   ```

### Auto-Retry vs. Escalate Decision

**Auto-retry conditions (transient failures):**
- Lock timeout (with `--force` flag)
- Parse errors (after template fix)
- GitHub API rate limit (after backoff)

**Escalate to CEO (persistent failures):**
- Execution failures (needs human judgment)
- Validation failures
- Permission errors
- Multiple consecutive failures

**Recovery commands:**
```bash
# Retry with force (stale lock)
scripts/worker/execute.sh --issue 42 --force

# Check worker status
scripts/worker/execute.sh --issue 42 --status

# Clean up worktree
scripts/worktree-remove.sh issue/42
```

### Cascade Handling

When a blocking issue fails:
1. Identify all dependent issues
2. Label as `cascade-blocked`
3. Post comment explaining blocker
4. Report full cascade to CEO
5. Present options for resolution

---

## Quick Actions

Shortcuts for common operations during active session.

### Approve N
Approve the execution plan for issue #N.

```bash
# Add thumbs up reaction to plan comment
gh api repos/OWNER/REPO/issues/comments/COMMENT_ID/reactions \
  --method POST -f content='+1'
```

### Retry N
Re-run a failed worker for issue #N.

```bash
gh issue edit N --remove-label "worker:failed"
scripts/worker/execute.sh --issue N
```

### Status
Quick oneliner status summary.

```bash
scripts/orchestrator/aggregate.sh --format oneliner
```

### Progress
Table view of all active workers.

```bash
scripts/orchestrator/aggregate.sh --format table --scope active
```

### Details N
Full details for specific issue.

```bash
gh issue view N --json number,title,labels,comments
scripts/orchestrator/graph.sh deps N
```

---

## Decision Workflow

When intent is DECISION, present options for blocked or failed items.

### Decision Process

1. **Identify blocked items:**
   ```bash
   gh issue list --label "blocked" --state open
   gh issue list --label "cascade-blocked" --state open
   ```

2. **Find root cause:**
   ```bash
   scripts/orchestrator/graph.sh deps ISSUE
   ```

3. **Present options:**
   ```
   Issue #43 is blocked by #42 (failed).

   Options:
   1. Fix #42 and retry - Resolve root cause first
   2. Skip dependency - Mark #43 as unblocked if no longer relevant
   3. Modify scope - Reduce #43 scope to remove dependency
   4. Abandon - Close both #42 and #43
   ```

4. **Execute CEO choice:**
   - Update labels accordingly
   - Re-dispatch if appropriate

---

## Correction Workflow

When intent is CORRECTION, halt or modify active work.

### Correction Process

1. **Identify scope:**
   - Specific issue: "stop #42"
   - All active: "stop everything"
   - Phase-level: "stop Phase 3 work"

2. **Take action:**
   ```bash
   # Stop specific worker
   scripts/orchestrator/dispatch.sh --issue 42 --force

   # Stop all workers (via trap in dispatch.sh)
   # Ctrl+C during dispatch, or kill background PIDs
   ```

3. **Update state:**
   ```bash
   gh issue edit 42 --remove-label "worker:executing" --add-label "worker:failed"
   gh issue comment 42 --body "## Stopped by orchestrator

   Work halted per CEO request.

   **Reason:** [reason from CEO]
   **State at stop:** [partial work description]"
   ```

4. **Handle cascade:**
   ```bash
   scripts/orchestrator/aggregate.sh --cascade 42
   ```

---

## Context Loading

When orchestrating, load standard context:

```bash
# Project context
cat .planning/PROJECT.md   # Project overview and decisions
cat .planning/STATE.md     # Current position and accumulated context
cat .planning/ROADMAP.md   # Phase structure and dependencies
```

Issue-specific context comes from the issue body itself.

---

## Session Behavior

### Active Session

During active conversation with CEO:
- Proactively report worker completions
- Alert on failures immediately
- Surface approval requests
- Stay silent when no state changes

### Session End

When CEO wraps up:
- Summarize session outcomes
- List pending items needing attention
- Provide resume instructions

```
Session Summary:
  - Created: 3 issues (#52, #53, #54)
  - Completed: 1 (#52 Foundation - Theme system)
  - In progress: 2 (#53, #54 awaiting approval)

Pending:
  - #53: Review plan and approve
  - #54: Review plan and approve

Resume: "Continue dark mode work" or "Status"
```

---

## Helper Scripts Reference

Located in `scripts/orchestrator/`:

| Script | Purpose | Key Functions |
|--------|---------|---------------|
| `intent.sh` | Classify CEO input | `classify_intent()` |
| `decompose.sh` | Task decomposition | `generate_decomposition_prompt()`, `validate_decomposition()`, `format_for_creation()` |
| `graph.sh` | Dependency management | `build_dependency_graph()`, `get_execution_order()`, `get_ready_issues()`, `detect_cascade()` |
| `dispatch.sh` | Worker dispatch | `dispatch_single()`, `dispatch_parallel()`, `dispatch_with_dependencies()` |
| `aggregate.sh` | Status aggregation | `format_oneliner()`, `format_table()`, `format_detailed()`, `detect_cascade()` |

---

## Error Handling Reference

### Common Errors and Recovery

| Error | Cause | Recovery |
|-------|-------|----------|
| "Lock held by another process" | Concurrent execution | Wait or use `--force` |
| "Cycle detected in dependency graph" | Circular dependencies | Re-decompose issues |
| "Missing Acceptance Criteria" | Invalid issue format | Update issue body |
| "Rate limit exceeded" | Too many API calls | Wait for reset |
| "Worker already executing" | Duplicate dispatch | Check status first |

### Escalation Path

1. Auto-recover if possible (transient errors)
2. Report to CEO with context and options
3. Never silently fail - always log and report

---

*Skill: orchestrate*
*Version: 2.0.0*
*Phase: 05-orchestration*

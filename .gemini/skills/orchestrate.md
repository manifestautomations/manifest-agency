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

## Intent Classification

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

### Classification Examples

- "Build the login page" -> DISPATCH
- "What's the status?" -> STATUS
- "The blocked items need attention" -> DECISION
- "Stop that work" -> CORRECTION
- "Tell me about the project" -> CONVERSATION

---

## Decomposition Workflow

When intent is DISPATCH, break CEO vision into actionable GitHub issues.

### Decomposition Process

1. **Understand the intent:**
   - What is the CEO trying to achieve?
   - What existing infrastructure can be leveraged?
   - Does this match an existing phase in ROADMAP.md?

2. **Check for existing work:**
   - If intent matches a planned phase, suggest using GSD command instead
   - Query open issues to avoid duplication

3. **Apply vertical slicing:**
   - Prefer end-to-end features over horizontal layers
   - Target S/M sizing (1-4 hours per issue)
   - First issue is "Foundation" if new infrastructure needed
   - Each issue should be independently shippable

4. **Define dependencies:**
   - Foundation issues have no dependencies
   - Feature issues depend on foundation
   - Use "Blocked by #N" format in issue body

5. **Present decomposition:**
   - Show CEO the planned issues before creating
   - Include: title, summary, acceptance criteria, dependencies
   - Await CEO approval before proceeding

### Decomposition Example

CEO: "We need dark mode"

Proposed decomposition:
```
Issue 1: Foundation - Theme system
  Summary: CSS variables, toggle component, localStorage persistence
  Acceptance: Toggle switches theme, persists on reload, applies globally
  Dependencies: None

Issue 2: Dark mode for dashboard
  Summary: Apply theme to dashboard components
  Acceptance: All dashboard widgets respect theme, readable in both modes
  Dependencies: Blocked by #1

Issue 3: Dark mode for settings
  Summary: Apply theme to settings pages
  Dependencies: Blocked by #1
```

### Issue Template

Use `templates/orchestrator/issue-decomposition.md` for issue body format.

Required sections (match parser.sh expectations):
- `## Summary` - What needs to be done
- `## Context` - Background and links
- `## Acceptance Criteria` - Definition of done
- `## Dependencies` - Blocked by references
- `## Notes` - Implementation hints

---

## Dispatch Workflow

After CEO approves decomposition, create issues and start workers.

### Dispatch Process

1. **Create issues in GitHub:**
   - Use issue template with placeholders filled
   - Capture created issue numbers

2. **Build dependency graph:**
   - Parse "Blocked by #N" from issue bodies
   - Validate no circular dependencies (tsort)

3. **Dispatch ready workers:**
   - Identify issues with no blocking dependencies
   - Call: `scripts/worker/execute.sh --issue N`
   - Respect max concurrent workers limit

4. **Report dispatch status:**
   - Tell CEO which issues were created
   - Which workers were dispatched
   - Which are waiting on dependencies

### Worker States

Track worker progress via GitHub labels:
- `worker:planning` - Worker is analyzing the issue
- `worker:awaiting-approval` - Plan ready, needs thumbs up
- `worker:executing` - Actively working
- `worker:complete` - Work finished successfully
- `worker:partial` - Partial completion, needs attention
- `worker:failed` - Execution failed

---

## Status Aggregation Workflow

When intent is STATUS, query GitHub and report progress.

### Status Process

1. **Determine scope:**
   - Active workers only (default)
   - Current phase
   - All project issues

2. **Query GitHub:**
   - Filter by worker labels
   - Include issue titles and states

3. **Format response:**
   - One-liner for quick check
   - Table for detailed progress
   - Full breakdown on request

### Status Formats

**One-liner:** "3 executing, 2 awaiting approval, 1 blocked"

**Table:**
```
Status | Issue | Title
-------|-------|------
  [>]  | #42   | Implement login flow
  [?]  | #43   | Add OAuth support
  [!]  | #44   | Setup theme system
```

Icons:
- `[+]` Complete
- `[>]` Executing
- `[?]` Awaiting approval
- `[x]` Blocked/Failed
- `[ ]` Pending

---

## Decision Workflow

When intent is DECISION, present options for blocked or failed items.

### Decision Process

1. **Identify blocked items:**
   - Query issues with `blocked` or `cascade-blocked` labels
   - Find root cause (which issue blocks which)

2. **Present options:**
   - For each blocked item, explain why it's blocked
   - Suggest: retry, skip dependency, modify scope, abandon

3. **Execute CEO choice:**
   - Update labels accordingly
   - Re-dispatch if appropriate

---

## Correction Workflow

When intent is CORRECTION, halt or modify active work.

### Correction Process

1. **Identify scope:**
   - Specific issue ("stop #42")
   - All active work ("stop everything")
   - Phase-level ("stop Phase 3")

2. **Take action:**
   - Kill running workers (signal handling)
   - Update labels to reflect stopped state
   - Report what was stopped

3. **Cascade handling:**
   - Identify dependent issues
   - Label as cascade-blocked
   - Report cascade impact

---

## Failure Handling

When workers fail, report to CEO with context and recovery options.

### Failure Response

1. **Gather context:**
   - Which issue failed
   - Error message/reason
   - Duration before failure
   - Related logs

2. **Identify cascade:**
   - Find issues blocked by the failed issue
   - Label as cascade-blocked

3. **Present options:**
   - Retry (for transient failures only)
   - Modify issue scope
   - Skip and continue
   - Abandon chain

### Auto-Retry Conditions

Only auto-retry for:
- Lock timeout (with `--force` flag)
- Parse errors (after template fix)

NEVER auto-retry:
- Execution failures (needs human judgment)
- Validation failures
- Permission errors

---

## Function Calling Definitions

<!-- TODO: Complete in Plan 05 - these are placeholders for Gemini function calling -->

### create_github_issues

Creates GitHub issues from decomposed tasks.

```
Parameters:
  issues: array of {
    title: string - Issue title (brief, actionable)
    summary: string - What needs to be done
    acceptance: array of strings - Acceptance criteria
    depends_on: array of numbers - Issue numbers this depends on
  }

Returns:
  created_issues: array of {number, title, url}
```

### dispatch_workers

Starts Claude workers for ready issues (no blocking dependencies).

```
Parameters:
  issue_numbers: array of numbers - Issues to dispatch

Returns:
  dispatched: array of {number, pid}
  blocked: array of {number, blocked_by}
```

### query_worker_status

Gets current status of workers.

```
Parameters:
  scope: "active" | "phase" | "all"
  format: "oneliner" | "table" | "detailed"

Returns:
  status: formatted string or JSON based on format
```

### halt_workers

Stops active workers.

```
Parameters:
  scope: "all" | array of issue numbers

Returns:
  stopped: array of {number, previous_state}
```

---

## Context Loading

When orchestrating, load standard context:

- `.planning/PROJECT.md` - Project overview and decisions
- `.planning/STATE.md` - Current position and accumulated context
- `.planning/ROADMAP.md` - Phase structure and dependencies

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

---

## Helper Scripts

Located in `scripts/orchestrator/`:

| Script | Purpose |
|--------|---------|
| `intent.sh` | Classify CEO input into categories |
| `decompose.sh` | Task decomposition helpers (future) |
| `dispatch.sh` | Dependency-aware worker dispatch (future) |
| `aggregate.sh` | Status aggregation helpers (future) |

---

*Skill: orchestrate*
*Version: 1.0.0*
*Phase: 05-orchestration*

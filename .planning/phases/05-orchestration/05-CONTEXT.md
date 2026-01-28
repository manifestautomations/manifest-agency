# Phase 5: Orchestration - Context

**Gathered:** 2026-01-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Gemini orchestrator receives CEO intent via Antigravity conversation, decomposes into GitHub issues, dispatches Claude workers via CLI, and aggregates status back to CEO. This is a reactive orchestrator (CEO initiates) with proactive updates during active sessions.

**In scope:** Intent parsing, task decomposition, worker dispatch, status aggregation, failure handling.
**Out of scope:** Proactive background notifications (Tier 2 future), autonomous scheduling, worker parallelization within a single task (Phase 6).

</domain>

<decisions>
## Implementation Decisions

### Intent Intake
- CEO communicates pure natural language intent via Antigravity conversation pane
- Orchestrator handles ALL GitHub issue creation (CEO never writes issues directly)
- Intent triggers: Natural language by default, optional explicit triggers (`/dispatch`, `/status`) for precision
- Confirmation gate before dispatch: Orchestrator shows decomposition, awaits CEO approval
- Stateless orchestrator: GitHub is truth, no persistent memory. STATE.md for meta-decisions.
- Trigger classification: DISPATCH (action words), STATUS (query words), DECISION (references blocked items), CORRECTION (stop/pause), CONVERSATION (none of above)

### Task Decomposition
- Target sizing: S/M (1-4 hours per issue), one issue = one PR
- Decompose anything over 4 hours into smaller issues
- Vertical slices preferred over horizontal layer splitting for cross-cutting concerns
- Foundation + features pattern for new infrastructure
- Roadmap awareness: If intent matches existing phase, suggest GSD command instead of re-decomposing
- Issue format matches parser.sh expectations: Summary + Acceptance Criteria + Context sections
- Dependencies declared via "Blocked by #N" in issue body

### Worker Dispatch
- Dispatch command: `scripts/worker/execute.sh --issue <N>`
- Dependency-aware parallel dispatch: Build graph, dispatch ready issues, wait for blockers
- Issue body contains file references; worker loads standard context (PROJECT.md, STATE.md, ROADMAP.md)
- GitHub labels track worker state: `worker:planning`, `worker:awaiting-approval`, `worker:executing`, `worker:complete`, `worker:failed`, `worker:partial`
- Stateless tracking: Query GitHub for active workers, no in-memory state
- CEO approves plans for now (Option A); auto-approval is future enhancement

### Failure Handling
- Report failures to CEO with context and options (retry, modify, abandon)
- Auto-retry ONLY for transient failures: lock timeout (with `--force`), parse errors (after fix)
- Never auto-retry execution failures (needs human judgment)
- Cascade awareness: Identify and report all issues blocked by failed issue
- Recovery commands documented: `--force`, `--status`, label cleanup, worktree cleanup

### Status Aggregation
- Format matches query: One-liner for quick check, table for progress, detailed breakdown on request
- Proactive during active session: Report completions, failures, approvals needed
- Stay silent when no state change
- Tiered aggregation: Phase (default), Project, Portfolio on demand
- Status icons: Complete, Executing, Needs approval, Blocked, Failed
- Session summary on wrap-up with resume instructions

### Gemini-Claude Bridge
- Gemini uses instructional skills (`.gemini/skills/`) — describes HOW to orchestrate
- Claude uses executable skills (`.claude/skills/`) — contains actual bash code
- Orchestrator dispatches via terminal command, does not execute GSD skills directly
- Issue template ensures workers can parse (Summary + Acceptance Criteria format)

### Claude's Discretion
- Polling cadence during active session (suggested: 60 seconds)
- Exact format of status tables and summaries
- Helper script organization (`scripts/orchestrator/`)
- Cache TTL for portfolio aggregation
- Retry backoff timing for transient failures

</decisions>

<specifics>
## Specific Ideas

- "The CEO is the visionary, the orchestrator is the translation layer between vision and GitHub work items"
- "Not writing code line by line. Walking the floor, checking in on teams, making decisions, pointing in the right direction."
- Natural conversation flow: CEO says "We need dark mode" → Orchestrator shows decomposition → CEO approves → Workers execute
- Confirmation pattern: Show planned issues with dependencies before creating
- Quick actions in status: "Approve 53" shortcut instead of requiring CEO to go to GitHub
- Vertical slice example: "Implement login flow end-to-end" not "Add auth to API layer" + "Add auth to UI layer"

</specifics>

<deferred>
## Deferred Ideas

- **Tier 2 Proactive Notifications:** Background execution, webhooks, push to inbox when Antigravity adds support
- **Auto-approval (Option B):** Orchestrator reviews plans programmatically and auto-approves when trust established
- **External notification channel:** Email/Discord alerts for status updates when CEO not in session
- **Scheduled briefings:** Cron-triggered status reports without CEO presence
- **Skill/workflow registration:** Define reusable `/ship`, `/status` commands in Antigravity (when skill system available)
- **CEO preference memory:** Track verbosity preferences, skip confirmation thresholds, etc.

</deferred>

---

*Phase: 05-orchestration*
*Context gathered: 2026-01-28*

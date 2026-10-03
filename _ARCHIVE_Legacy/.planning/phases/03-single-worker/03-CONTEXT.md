# Phase 3: Single Worker - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate that one Claude worker can execute commands, report results, and provide observability. Worker is manually invoked via CLI, operates in an isolated git worktree, updates GitHub issues with progress, creates PRs for completed work, and logs all actions in structured JSON format. This phase establishes the core worker loop that later phases will orchestrate and parallelize.

</domain>

<decisions>
## Implementation Decisions

### Worker Invocation
- **Manual CLI invocation**: `claude --skill worker:execute --issue 42`
- **Structured issue templates** required with Objective, Requirements, Acceptance Criteria sections
- **Confirmation step before execution** — worker posts plan as issue comment, waits for 👍 reaction
- **No timeout waiting for approval** — worker posts plan, sets `worker:awaiting-approval` label, exits cleanly
- **Human re-runs command** after approving to continue execution
- **Label-based state machine**: `worker:ready` → `worker:planning` → `worker:awaiting-approval` → `worker:executing` → `worker:complete` (or `worker:partial`/`worker:failed`)
- **Lock file mechanism** at `.worker/locks/issue-42.lock` prevents concurrent execution
- **Lock staleness threshold**: 30 minutes — offer `--force` flag if stale
- **`--status` flag** shows detailed progress from log file

### Execution Reporting
- **Milestone-only GitHub comments**: Plan → Start → Complete/Failure (3 total)
- **Final comment** includes detailed breakdown in collapsible `<details>` sections
- **Failure comments** include full error context and recovery options
- **Comprehensive JSON logging** — every event type (lifecycle, context, environment, execution, file, git, GitHub, error, decision)
- **Event schema** with `timestamp`, `event_type`, `event_id`, `session_id`, `data`
- **Logs gitignored**: `.worker/logs/` and `.worker/locks/` not committed
- **Directory structure committed**: `.gitkeep` files preserve structure, `config.json` for worker config
- **Structured terminal output** with prefixes (`[worker]`, `[task N/M]`, `[git]`, `[gh]`, `[error]`) and symbols (✓ ✗ ⏳ →)
- **`--quiet` flag** available for minimal output

### Worktree Lifecycle
- **Deferred creation** — worktree created at execution start (after approval), not plan time
- **Read-only exploration** during planning phase from main repo
- **Naming pattern**: `{repo-name}-issue-{issue-number}` as sibling directory (e.g., `../manifest-automations-issue-42`)
- **Branch naming**: `issue/{N}` (e.g., `issue/42`)
- **Remove after PR merged** — conservative cleanup (manual for Phase 3)
- **Crash detection** via stale lock file + incomplete log (no `session_end` event)
- **Three recovery options**: `--inspect` (view crash state), `--resume` (continue from checkpoint), `--restart` (discard and start fresh)
- **Aggressive staging after each task** — changes survive crashes via `.git/index`
- **Single commit at end** — clean history, one issue = one commit
- **Commit message format** includes "Resolves #42", task checklist, Co-Authored-By

### Failure Handling
- **No auto-recovery** — fail immediately, excellent error reporting, wait for human guidance
- **Human recovery via issue comments**: `retry`, `skip`, `commit-partial`, `abort`
- **Stop at first failure** — fail fast, clear partial state reporting
- **`worker:partial` label** for partial completion state
- **10 minute per-command timeout** as safety net (configurable via `--command-timeout`)
- **Warning at 80%** of timeout (8 minutes)
- **`--no-timeout` flag** for known slow operations
- **Graceful termination**: SIGTERM → 10 second grace period → SIGKILL
- **GitHub API retries** for transient errors (rate limit, 5xx, network): 3 attempts with exponential backoff
- **Permanent errors** (401, 404, 422) fail immediately
- **Rate limit handling**: Wait up to 5 minutes, fail if longer
- **Critical vs non-critical operations**: Label updates can warn and continue; PR creation must succeed

### Claude's Discretion
- Exact skill file structure and internal organization
- Specific jq query patterns for log analysis
- Lock file JSON structure details
- Exact terminal color/formatting choices
- Specific test file organization

</decisions>

<specifics>
## Specific Ideas

- Worker skill location: `.claude/skills/worker/execute.md` with supporting skills (setup, report)
- Plan comment should show "Based on main @ {sha}" for traceability
- Commit message should include task checklist showing what was done
- Log files should be queryable with standard jq patterns
- Terminal output should be readable by both humans and basic log parsers
- Recovery commands parsed from issue comments on next worker invocation

</specifics>

<deferred>
## Deferred Ideas

- **Orchestrator dispatch** — Phase 5 (Gemini dispatches via claude-code CLI)
- **Automated triggering** (label polling, GitHub Actions) — Phase 5
- **AI fallback parsing** for unstructured issues — Phase 4
- **Configurable confirmation** (skip for trusted contexts) — Phase 4
- **Multiple concurrent workers** — Phase 6
- **Centralized logging** (external storage, aggregation) — Phase 4+
- **Auto-recovery with retry logic** — Phase 4
- **Dependency-aware task execution** — Phase 4
- **`--json` output mode for CI/CD** — Phase 4
- **Post-merge worktree cleanup automation** — Phase 4

</deferred>

---

*Phase: 03-single-worker*
*Context gathered: 2026-01-27*

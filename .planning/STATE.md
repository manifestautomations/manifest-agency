# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-26)

**Core value:** Complete loop where CEO dispatches intent, orchestrator routes, Claude executes, results land in GitHub with status reporting back.
**Current focus:** Phase 5 - Orchestration

## Current Position

Phase: 5 of 7 (Orchestration)
Plan: 2 of 5 complete
Status: In progress
Last activity: 2026-01-28 — Completed 05-02-PLAN.md (Orchestrator Helpers)

Progress: [███████░░░] 76%

## Performance Metrics

**Velocity:**
- Total plans completed: 17
- Average duration: 4.5 min
- Total execution time: 1.25 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 6min | 2min |
| 02-github-coordination | 5 | 20min | 4min |
| 03-single-worker | 4 | 24min | 6min |
| 04-trust-guardrails | 5 | 26min | 5.2min |

**Recent Trend:**
- Last 5 plans: 04-01 (3min), 04-02 (6min), 04-03 (5min), 04-04 (5min), 04-05 (7min)
- Trend: Infrastructure tasks average 4-7min, documentation heavier tasks 10-15min

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- GitHub as coordination layer (auditable, human-readable, no proprietary state)
- Hook-based trust (enforcement at execution boundaries, not runtime)
- Declarative agent definitions (CEO invokes intent, agents encode implementation)
- Dynamic worktrees (isolation without merge conflicts, outcome-based cleanup)
- Agents as disposable resources (scale to work, not the other way around)

**From 01-01 (Repository Foundation):**
- Local git config for submodule behavior (not global)
- LF line endings normalized across platform via .gitattributes

**From 01-02 (Agent Manifest Schema):**
- JSON Schema draft-07 for wide IDE compatibility
- Strict validation (additionalProperties: false) to catch typos
- Optional triggers for both direct invocation and auto-routing
- Provider-specific extensions in providers.* namespace

**From 01-03 (Worktree Automation):**
- Sibling naming pattern for worktrees (../repo-name-branch-name/)
- Safety checks in remove script (uncommitted changes detection)
- Outcome-based cleanup (report stale, manual removal)
- Observability-first with list command (human and machine-readable)

**From 02-01 (Prerequisites):**
- Cache directory structure preserved in git via .gitkeep files while ignoring cached content
- Template placeholders use UPPERCASE format for script substitution
- Progress comments use HTML comment blocks for machine parsing

**From 02-02 (GitHub Project Board):**
- View creation is manual-only due to GitHub API limitation (no createProjectV2View mutation)
- Field ID caching in .cache/github/ with TTL approach reduces API calls 100x
- Inline JSON construction with jq avoids external file dependencies
- Idempotency pattern: check for resource existence before creation

**From 02-03 (Issue Lifecycle Management):**
- Issue number as positional argument (not --issue flag) for natural CLI usage
- Progress metadata embedded in HTML comments for machine parsing without visual clutter
- Blocker comments automatically add 'blocked' label for visibility
- GraphQL project item lookup pattern: query repository issue projectItems

**From 02-04 (PR Management and Project Queries):**
- PR metadata captured in structured table (agent, duration, model, trust level)
- Query script supports multiple output formats (json, table, list) for different consumers
- Generic update script handles both text and single select fields via type detection
- Template loading and placeholder replacement pattern for PR bodies

**From 02-05 (GitHub Actions and Documentation):**
- GitHub Actions workflow uses PROJECT_PAT secret for Projects API access (GITHUB_TOKEN lacks project permissions)
- Workflow handles PR opened/ready_for_review and merged events for status automation
- PR body "Closes #N" pattern triggers both GitHub native issue closure and custom status automation
- Comprehensive README structure: Prerequisites → Quick Start → Script Reference → Workflows → Troubleshooting

**From 03-01 (Worker Infrastructure Setup):**
- Worker configuration in .worker/config.json (600s command timeout, 1800s lock staleness)
- GitHub API retry strategy (3 attempts with exponential backoff, 5 min max rate limit wait)
- .gitkeep pattern for directory preservation from Phase 2 applied to worker infrastructure
- Warning threshold at 80% of timeout for early detection

**From 03-02 (Worker Core Libraries):**
- mkdir-based atomic locking (flock not available on Windows/MINGW64)
- Lock directories instead of lock files with metadata.json for staleness detection
- jq for all JSON generation to ensure proper escaping in logs
- awk for robust multi-line section extraction from issue bodies
- Trap-based cleanup ensures lock release on EXIT/SIGTERM/SIGINT

**From 03-03 (Worker Execution Skill):**
- State machine via GitHub labels - survives crashes, human-visible in UI
- Approval workflow: post plan, exit cleanly, resume on re-run after thumbs up reaction
- Execution placeholder pattern: skill provides orchestration, Claude provides implementation
- 6 worker states: planning, awaiting-approval, executing, complete, partial, failed
- Exit-and-resume pattern for human approval gates (no polling/waiting)

**From 03-04 (Comment Templates and Documentation):**
- Standalone bash script for worker invocation (not slash command) - enables Phase 5 orchestrator dispatch
- `scripts/worker/execute.sh --issue N` as primary entry point for human and programmatic invocation
- Claude CLI invoked via `claude -p "prompt"` for AI implementation work within orchestration shell
- gh api paths must omit leading slash on Windows (Git Bash converts /repos to filesystem path)
- All scripts require explicit execute permissions in git (mode 100755) for GitHub Actions

**From 04-01 (Trust Guardrails Configuration):**
- yq installed to $HOME/bin instead of /usr/bin (Windows/MINGW64 permission constraints)
- Safety floor patterns use regex for flexibility while remaining strict on critical operations
- Trust level 0 blocks ALL operations (even low severity) for complete lockdown capability
- Violation points decay with clean actions (5 points per action) to reward good behavior

**From 04-02 (Audit Infrastructure):**
- SHA-256 hash chaining for tamper detection (each entry links to previous via checksum)
- Genesis checksum of 64 zeros as chain start point
- Daily log file rotation (YYYY-MM-DD.audit.jsonl) prevents single file growth
- chain.json tracks last checksum for quick access without parsing all logs
- JSONL format (single-line JSON) for append-only operations
- Audit logs ignored in git, chain.json tracked for team verification

**From 04-03 (Validator Library):**
- Bash regex doesn't support \s - convert to [[:space:]] for pattern matching
- Secure glob-to-regex requires explicit literal handling for / and leading dots
- Trust scores tracked in git (team visibility), violation logs ignored (forensics only)
- Deny patterns checked before allow patterns (deny always wins)
- Safety floor patterns ALWAYS block regardless of trust level (11 critical patterns)

**From 04-04 (Hooks Library):**
- TTY detection using [ -t 0 ] for interactive terminal check
- Non-TTY mode falls back to GitHub approval workflow (prevents silent failures)
- Confirmation timeout defaults to 30 seconds with deny-by-default (safe default)
- Trust decay applied after every successful command execution (-5 points per clean action)
- Windows compatibility: text-based severity markers instead of emojis

**From 04-05 (Guardrails Integration):**
- Worker logs lifecycle events (worker_start, execution_start, execution_complete, execution_failed) - NOT individual Claude tool calls
- Claude CLI's --allowedTools flag handles tool-level restrictions
- Default agent name 'claude-worker' for all worker executions
- Guardrails enabled by default (enabled: true in config)
- Default trust level 2 (safe write) for new agents

**From 05-01 (Gemini Orchestrator Skill):**
- Orchestrator skill location: .gemini/skills/orchestrate.md
- Instructional skill pattern (describes HOW, does not execute)
- Intent classification: DISPATCH, STATUS, DECISION, CORRECTION, CONVERSATION
- Confirmation gate before all dispatch operations

**From 05-02 (Orchestrator Helpers):**
- Vertical slice prompts include Foundation+Features pattern guidance
- Dependency format 'Blocked by #N' matches CONTEXT.md convention
- tsort exit code for cycle detection (POSIX standard)
- jq scan() for case-insensitive pattern extraction from issue bodies
- Orchestrator helpers in scripts/orchestrator/ directory

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-01-28T13:38:34Z
Stopped at: Completed 05-02-PLAN.md (Orchestrator Helpers)
Resume file: None

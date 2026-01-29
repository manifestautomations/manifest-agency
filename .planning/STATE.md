# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-26)

**Core value:** Complete loop where CEO dispatches intent, orchestrator routes, Claude executes, results land in GitHub with status reporting back.
**Current focus:** Phase 7 CEO Interface - COMPLETE

## Current Position

Phase: 7 of 7 (CEO Interface) - COMPLETE
Plan: 6 of 6 complete (100%)
Status: Phase 7 Complete - All plans executed
Last activity: 2026-01-29 - Completed 07-07-PLAN.md (Inbox Integration)

Progress: [==========] 100% (Phase 7)
Overall:  [==========] 100% (32 of 32 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 32
- Average duration: 4.4 min
- Total execution time: 2.45 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 6min | 2min |
| 02-github-coordination | 5 | 20min | 4min |
| 03-single-worker | 4 | 24min | 6min |
| 04-trust-guardrails | 5 | 26min | 5.2min |
| 05-orchestration | 5 | 20min | 4min |
| 06-worker-parallelization | 7 | 32min | 4.6min |
| 07-ceo-interface | 5 | 28min | 5.6min |

**Recent Trend:**
- Last 5 plans: 07-03 (9min), 07-04 (5min), 07-05 (8min), 07-07 (3min)
- Trend: Consistent 3-9min execution per plan

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
- Comprehensive README structure: Prerequisites -> Quick Start -> Script Reference -> Workflows -> Troubleshooting

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

**From 05-03 (Worker Dispatch):**
- wait -n for parallel job control (bash 4.3+ required)
- Associative array worker_pids for PID tracking
- Wave-based dependency dispatch via graph.sh integration
- JSON logging consistent with worker logger format
- Status queries both local PIDs and GitHub labels

**From 05-04 (Status Aggregation):**
- Tiered output formats: oneliner (quick count), table (progress view), detailed (full JSON)
- Text-based icons for Windows compatibility: [OK], [..], [??], [XX], [--]
- Cascade detection via 'Blocked by #N' pattern matching in issue bodies
- Transitive cascade analysis (issues blocked by blocked issues)
- Scope filtering: active (worker-labeled only), phase (open issues), all

**From 05-05 (Skill and Documentation):**
- Function calling definitions map to terminal command invocations
- Skill describes HOW to orchestrate, scripts execute the work
- Dispatch state stored in .worker/dispatch/ (ephemeral, gitignored)
- README documents all scripts with usage examples and troubleshooting

**From 06-01 (Graph Parser Library):**
- Use yq (mikefarah v4.44+) for YAML parsing - no regex-based parsing due to YAML complexity
- Return exit code 1 when no graph found - enables serialization fallback
- tsort format is 'dependency dependent' where dependency must complete before dependent
- Parallelization threshold: 3+ independent tasks OR 2 tasks with total duration > 5 minutes
- Graph extraction pattern: sed to find section, extract YAML fences, validate with yq

**From 06-02 (Sub-Agent Scope Library):**
- Agent ID format includes wave number and task slug for readability
- Max nesting depth of 2 enforced (root -> sub-agent -> sub-sub-agent)
- Glob pattern matching supports wildcards in parent scope
- Scope escalation validation occurs before sub-agent spawn
- Agent registry uses yq for structured YAML updates

**From 06-03 (Timeout Manager):**
- timeout -k for two-stage termination (SIGTERM at 80%, SIGKILL at 100%)
- Extension bounds: max 120s per extension, max 2 per agent
- Trust level 3+ gets auto-approval for extensions
- Per-agent timeout state tracked in .worker/agents/{id}/timeout.json

**From 06-04 (Scope Validator and Spawner):**
- Pre-flight validation BEFORE spawning any agents (not during execution)
- Associative arrays for PID tracking instead of files
- Let-finish pattern on wave failure to salvage partial work
- Immediate PID capture after & prevents race conditions
- validate_wave_scopes called before any spawn_subagent calls

**From 06-05 (Wave Aggregation and Worker Integration):**
- Wave commits include all sub-agent work in single atomic commit
- Verification pipeline: structural (file exists) then syntactic (code parses)
- Rollback unstages and restores without history pollution
- Serial execution is default when no execution graph present
- Worker execute.sh integration with automatic parallelization detection
- PLAN.md location: .worker/plans/issue-N-PLAN.md (future integration point)
- Conditional execution in execute.sh: serial (existing) or parallel (sub-agents)
- aggregate_wave_results, create_wave_commit, rollback_wave, handle_wave_failure functions
- execute_with_subagents function for wave-based parallel execution with DAG traversal

**From 06-07 (Gap Closure for UAT Failures):**
- Include guards for sourced bash libraries ([[ -n "${_VAR_SOURCED:-}" ]] && return 0)
- WORKER_SCRIPT_DIR preserves path before sourcing Phase 3/4 libs that overwrite SCRIPT_DIR
- Remove set -euo pipefail from sourced libraries - causes issues with interactive shells
- Phase 6 libs sourced via WORKER_SCRIPT_DIR, Phase 3/4 libs via LIB_DIR

**From 07-01 (CEO Skill Infrastructure):**
- Agent Skills open standard format for SKILL.md (name, description, allowed-tools, context)
- disable-model-invocation: true for briefing and approve skills (manual-only for safety)
- Approval state structure: pending/approved/denied subdirectories with registry.jsonl audit trail
- .gitkeep pattern extended to .worker/approvals/, .worker/briefings/, .worker/cache/

**From 07-02 (Dashboard Data Aggregation):**
- Cache stable metrics (trust, velocity) with 5-minute TTL
- Always fetch live data for dynamic metrics (agents, approvals)
- Script invocation via `bash -c '. script.sh'` for MINGW64 compatibility
- Mustache-style placeholders in dashboard template for rendering
- Cross-platform date handling (GNU/BSD fallback pattern)

**From 07-03 (Approval Workflow):**
- Critical violations use infinite timeout (9999-12-31T23:59:59Z) - never auto-deny
- Re-source guard skipped when script run directly (BASH_SOURCE[0] == $0)
- Delegation disabled by default in config, requires explicit CEO enablement
- Non-delegatable types: trust_promotion and critical_violation (CEO-only)
- Stale threshold: 2 hours (warning), Auto-deny threshold: 24 hours
- Approval state transitions via atomic file move (pending -> approved/denied)
- registry.jsonl as append-only audit log for all state changes

**From 07-04 (Briefing Generation):**
- Tasks 1 and 2 combined - timestamp tracking integrated into initial script
- Five sections in priority order: Blockers > Overnight > Health > Progress > Outlook
- Section collapsing: empty sections not rendered (one-screen target: 25-30 lines)
- Action links pattern: [Approve](cmd:approve id) for CLI integration
- Timestamp-based windowing for "since last briefing" calculations
- History archival: YYYY-MM-DD.md with 30-day retention

**From 07-05 (Dashboard Rendering and Skill Finalization):**
- Source-based script execution for MINGW64 compatibility (bash -c 'source script.sh')
- Inline heredoc templates for cross-platform reliability (avoid complex sed)
- 10-segment ASCII progress bar format: [=====     ]
- Error Handling sections in all SKILL.md files for troubleshooting guidance

**From 07-07 (Inbox Integration):**
- Notification tiers: immediate (critical), delayed (2h batch), silent (no push)
- CEO modes filter delivery: dnd (immediate only), normal (immediate+delayed), verbose (all)
- Duplicate protection using daily identifier for briefings
- Action button format: action://approve?id=X for Inbox integration
- Inbox messages stored in .worker/inbox/ with timestamped filenames

### Pending Todos

None - All phases complete.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-01-29T07:29:02Z
Stopped at: Completed 07-07-PLAN.md (Inbox Integration) - PHASE 7 COMPLETE
Resume file: None

## Project Completion Status

All 7 phases and 32 plans have been executed successfully:

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 01 | Foundation | 3 | Complete |
| 02 | GitHub Coordination | 5 | Complete |
| 03 | Single Worker | 4 | Complete |
| 04 | Trust Guardrails | 5 | Complete |
| 05 | Orchestration | 5 | Complete |
| 06 | Worker Parallelization | 7 | Complete |
| 07 | CEO Interface | 5 | Complete |

**Total:** 32 plans executed in approximately 2.5 hours

# Architecture

**Analysis Date:** 2026-01-29

## Pattern Overview

**Overall:** Multi-agent orchestration system using earned autonomy with layered trust enforcement.

**Key Characteristics:**
- Stateless orchestration layer (state lives in GitHub)
- Dependency-aware parallel execution via topological sorting
- Progressive trust levels controlling agent capabilities
- Audit chain with hash verification for all operations
- Sub-agent wave execution for parallelization within single tasks

## Layers

**CEO/Human Interface Layer:**
- Purpose: Executive decision making and approvals
- Location: `.claude/skills/ceo-dashboard/`
- Contains: Dashboard skill, briefing skill, approval workflow scripts
- Depends on: Worker status queries, audit logs, approval state
- Used by: Human operators via Claude Code

**Orchestration Layer:**
- Purpose: Decompose intent into issues, manage dependencies, dispatch workers
- Location: `scripts/orchestrator/`
- Contains: Intent classification, decomposition, dependency graph, dispatch, status aggregation
- Depends on: GitHub API (gh CLI), worker state tracking
- Used by: Gemini multi-agent orchestrator

**Worker Execution Layer:**
- Purpose: Execute individual GitHub issues in isolated worktrees
- Location: `scripts/worker/execute.sh`, `.claude/skills/worker/`
- Contains: Issue parsing, planning, approval gating, worktree management
- Depends on: Git, GitHub CLI, sub-agent spawning, audit logging
- Used by: Orchestrator dispatcher

**Sub-Agent Parallelization Layer:**
- Purpose: Execute complex tasks as parallel waves of independent subtasks
- Location: `scripts/worker/`, `.worker/agents/`
- Contains: Execution graph parsing, wave spawning, result aggregation, salvage logic
- Depends on: Task definitions, dependency tracking per-wave
- Used by: Worker execution when execution graph detected

**Trust & Guardrails Layer:**
- Purpose: Enforce capabilities, scope access, audit all actions
- Location: `.worker/` (config, approvals, audit), `.claude/skills/worker/lib/`
- Contains: Trust level enforcement, scope validation, hash-chained audit trail
- Depends on: Agent constraints, approval registry, violation tracking
- Used by: All layers for authorization

**GitHub Coordination Layer:**
- Purpose: Issue/PR lifecycle, label-based state machine, status tracking
- Location: `scripts/github/`
- Contains: Issue creation, PR automation, label management, status updates
- Depends on: GitHub API (gh CLI)
- Used by: Orchestrator, workers

## Data Flow

**CEO Intent to PR (Canonical Flow):**

1. CEO inputs intent via `/briefing`, `/dashboard`, or `/approve` commands
2. Gemini orchestrator classifies intent (DISPATCH, STATUS, DECISION, etc.)
3. For DISPATCH intent: `intent.sh` → `decompose.sh prompt` → Gemini generates vertical slices
4. `decompose.sh validate` checks for cycles, missing fields
5. `decompose.sh format` → `gh issue create` creates GitHub issues with metadata
6. `graph.sh validate` confirms dependency DAG, `graph.sh order` determines execution sequence
7. `dispatch.sh --with-dependencies` spawns workers respecting dependencies:
   - Wave 1: All issues with no blockers
   - Wave N: Issues where all dependencies are complete
8. Worker entry point (`execute.sh --issue N`) acquires lock, parses issue
9. `execute.sh` generates plan, posts as comment, waits for 👍 approval
10. On approval: Creates worktree `issue/{N}`, invokes Claude for implementation
11. Claude either:
    - (Serial mode) Makes changes directly in worktree
    - (Parallel mode) Extracts execution graph, spawns sub-agents in waves
12. Worker commits changes, creates PR, updates GitHub labels
13. Orchestrator aggregates status via `aggregate.sh`, reports to CEO inbox

**Status Query Flow:**

1. CEO: `/dashboard` or `/briefing` command
2. `aggregate-status.sh` scans `.worker/` directory:
   - Agent status from `agents/*/` directories
   - Approval counts from `approvals/{pending,approved,denied}/`
   - Violation scores from `violations/trust-scores.json`
   - Audit events from `audit/chain.json`
3. `render-dashboard.sh` formats for display (ASCII art with caching)
4. Results cached for 5 minutes (except live metrics)

**Approval Decision Flow:**

1. Agent requests approval (trust promotion, scope access, critical violation)
2. Approval file created in `.worker/approvals/pending/` with metadata
3. Notification pushed to CEO inbox (tier-dependent: immediate, delayed, or silent)
4. CEO runs `/approve` command
5. `approval-workflow.sh` shows context (agent, reason, deadline)
6. CEO: approve/deny triggers decision
7. Approval moved to `approved/` or `denied/`, registry updated
8. Agent notified via `.worker/approvals/` registry
9. Trust level adjusted, audit event logged

## Key Abstractions

**Dependency Graph (DAG):**
- Purpose: Model issue dependencies and determine execution order
- Examples: `scripts/orchestrator/graph.sh`, issue bodies with "Blocked by #N"
- Pattern: Issues declare `Blocked by #N` in body, `graph.sh` extracts edges, `tsort` gives topological order

**Label State Machine:**
- Purpose: Track worker progress without database
- Examples: `worker:planning` → `worker:awaiting-approval` → `worker:executing` → `worker:complete`
- Pattern: GitHub labels as finite state, issue comments for metadata

**Execution Graph (within task):**
- Purpose: Define parallel subtasks and their dependencies
- Examples: YAML blocks in issue body or `.worker/plans/issue-N-PLAN.md`
- Pattern: Tasks with `id`, `name`, `command`, `write_scope`, `depends_on`; processed in waves

**Audit Chain:**
- Purpose: Immutable log of all significant operations
- Examples: `.worker/audit/chain.json` with hash verification
- Pattern: Each event references previous SHA256, enabling tamper detection

**Trust Levels:**
- Purpose: Progressive autonomy grant based on performance
- Examples: Levels 0-4 with increasing capabilities (read-only → full autonomy)
- Pattern: Constraints in `.worker/agents/{ID}/constraints.json` enforced before execution

**Worktree (Git isolation):**
- Purpose: Separate working directory per task to avoid conflicts
- Examples: `manifest-automations-issue-42/` sibling to main repo
- Pattern: Created fresh per issue, independent commits/pushes, cleaned after PR merge

## Entry Points

**Human Entry Points:**

`/briefing` (`.claude/skills/ceo-dashboard/briefing.SKILL.md`):
- Triggers: CEO command
- Responsibilities: Generate daily briefing, deliver to inbox, archive history

`/dashboard` (`.claude/skills/ceo-dashboard/SKILL.md`):
- Triggers: CEO command
- Responsibilities: Aggregate live metrics, render executive view

`/approve` (`.claude/skills/ceo-dashboard/approve.SKILL.md`):
- Triggers: CEO command
- Responsibilities: List pending approvals, handle approval/deny, update audit trail

**Orchestrator Entry Points:**

`scripts/orchestrator/intent.sh`:
- Triggers: Gemini skill
- Responsibilities: Classify CEO input (DISPATCH, STATUS, DECISION, CORRECTION, CONVERSATION)

`scripts/orchestrator/decompose.sh`:
- Triggers: Gemini skill (after intent classification)
- Responsibilities: Generate decomposition prompt, validate JSON, format for issue creation

`scripts/orchestrator/dispatch.sh`:
- Triggers: Gemini skill (after issue creation)
- Responsibilities: Manage worker dispatch (single, parallel, or dependency-ordered waves)

**Worker Entry Point:**

`scripts/worker/execute.sh --issue N`:
- Triggers: Orchestrator `dispatch.sh` or manual command
- Responsibilities: Lock acquisition, issue parsing, plan generation, approval gating, execution, PR creation

## Error Handling

**Strategy:** Multi-level recovery with audit trail

**Patterns:**

- **Lock Mechanism**: `acquire_lock` with timeout detection; `--force` override for crash recovery (`scripts/worker/execute.sh` line 145)
- **Approval Timeout**: Issues in `worker:awaiting-approval` auto-fail after 24h without 👍 reaction
- **Dependency Cascade**: Failed issue blocks dependents; `graph.sh cascade` shows impact
- **Wave Salvage**: If sub-agent wave fails, `handle_wave_failure` attempts partial salvage (partial commit of successful subtasks)
- **Worktree Cleanup**: Stale worktrees cleaned via `scripts/worktree-cleanup.sh --days=7`
- **Audit Logging**: All errors logged to `audit/chain.json` with SHA256 chain, enabling root cause analysis

## Cross-Cutting Concerns

**Logging:**
- Worker: Structured JSON events to `.worker/logs/issue-{N}-{TIMESTAMP}.jsonl`
- Orchestrator: Events to `dispatch.jsonl` with issue/task correlation
- All: Timestamp in UTC ISO format, traceability fields included

**Validation:**
- Issue bodies: Must have `## Summary` and `## Acceptance Criteria` sections
- Decomposition: JSON schema validation in `decompose.sh validate`
- Dependency graph: Cycle detection via `graph.sh validate`
- Execution graph: DAG validation before wave spawning

**Authentication:**
- GitHub: Via `gh auth` (OAuth token stored by gh CLI)
- Agents: Trust level enforced via `.worker/agents/{ID}/constraints.json`
- Approvals: CEO identity via Claude Code context

**Concurrency Control:**
- Worker lock: File-based at `.worker/locks/issue-{N}.lock`
- Parallel dispatch: `--max-concurrent` limits simultaneous workers (default 3)
- Sub-agent waves: Sequential waves within issue, parallel agents within wave

**Scope Enforcement:**
- Write scope per sub-agent: Array of allowed file patterns in execution graph
- File access tracking: All writes logged to audit trail
- Cross-workspace blocks: Approval required via `.worker/approvals/pending/` for multi-project access

---

*Architecture analysis: 2026-01-29*

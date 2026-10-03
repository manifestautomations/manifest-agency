# Architecture

**Analysis Date:** 2026-01-31

## Pattern Overview

**Overall:** Hierarchical Command-Skill-Agent pattern with multi-workspace orchestration through earned autonomy and trust gates.

**Key Characteristics:**
- **Trust-based autonomy**: Progressive agent independence based on demonstrated competence
- **Multi-workspace management**: Central orchestration coordinating multiple project workspaces with isolation boundaries
- **Workflow hierarchy**: Commands (triggers) → Skills (processes) → Agents (actors) layering
- **State machine execution**: Explicit phase tracking through labeled states for reproducibility and failure recovery
- **Audit-first design**: Every action logged with timestamp, identity, rationale, and reversibility

## Layers

**Agency Layer:**
- Purpose: Orchestrate multiple workspaces, enforce trust system, manage CEO interface
- Location: `.claude/`, `.planning/`, `scripts/dispatch/`, `scripts/worker/`
- Contains: Skills (CEO dashboard, briefing, worker execution), commands, trust enforcement
- Depends on: Git workflow, GitHub API, submodule references
- Used by: CEO interface (Anti-Gravity Agent Manager), workspace dispatch system

**Workspace Layer:**
- Purpose: Individual project context with isolated trust ceiling and work tracking
- Location: `projects/[workspace-name]/`
- Contains: Project-specific CLAUDE.md, trust-ledger.md, planning docs, source code
- Depends on: Agency configuration, parent trust ceiling, workspace discovery
- Used by: Agent execution, phase-based planning, project-specific commands

**Execution Layer:**
- Purpose: Execute work from GitHub issues through isolated worktrees with approval gates
- Location: `scripts/worker/`, `scripts/dispatch/`, `.claude/skills/worker/`
- Contains: Locking, parsing, validation, worktree lifecycle, subagent spawning
- Depends on: Git worktrees, GitHub API, lock mechanism, audit trail
- Used by: Issue dispatch, human approval workflow, PR creation

**Persistence Layer:**
- Purpose: Track state across sessions through structured planning docs and audit logs
- Location: `.planning/phases/`, `.worker/audit/`, `.worker/approvals/`, `.worker/cache/`
- Contains: BRIEF → RESEARCH → PLAN → SUMMARY progression, approval records, trust scores
- Depends on: Markdown formatting, JSON serialization, file system
- Used by: Context handoffs, trust recalculation, CEO visibility

## Data Flow

**Issue → Execution → PR Flow:**

1. **Discovery**: GitHub issue created with Summary and Acceptance Criteria
2. **Locking**: Worker acquires exclusive lock (`.worker/lock/issue-N.lock`)
3. **Planning**: Issue parsed, execution plan generated, posted as comment
4. **Approval Gate**: CEO reviews plan, approves via reaction emoji
5. **Worktree Creation**: Isolated git worktree created (`../<repo>-issue-N/`)
6. **Execution**: Claude implements changes in worktree with audit logging
7. **Commit & PR**: Single atomic commit, PR created with execution context
8. **Cleanup**: Worktree removed, lock released, issue labeled complete
9. **Audit Trail**: Complete journey recorded in `.worker/audit/chain.json`

**State Management:**

- **Issue Labels**: Machine-readable state transitions (worker:planning → worker:awaiting-approval → worker:executing → worker:complete)
- **Lock Files**: Prevent concurrent execution and detect stale processes (staleness threshold: 1800 seconds)
- **Approval Registry**: `.worker/approvals/pending/` and `.worker/approvals/approved/` track decision flow
- **Audit Chain**: `.worker/audit/chain.json` contains chronological record of all state changes

## Key Abstractions

**Workspace:**
- Purpose: Represents a managed project with its own trust ceiling, planning context, and execution boundaries
- Examples: `projects/test-project/`, `projects/high-trust-workspace/`
- Pattern: Git submodule + local trust-ledger.md; inherits parent's trust ceiling
- Discovery: Automatic from git `.gitmodules` during startup

**Skill:**
- Purpose: Reusable workflow that orchestrates multiple tools and scripts
- Examples: `ceo-dashboard`, `worker-execute`, `briefing`
- Pattern: SKILL.md metadata + shell script implementation; invoked with named arguments
- Integration: Appears in agents.md under `skills:` array for retrieval-based reasoning

**Command:**
- Purpose: Lightweight, single-action trigger that may invoke a skill
- Examples: `/worker-execute --issue 42`, `/ceo-dashboard --show-blocked`
- Pattern: Markdown file in `.claude/commands/` that documents invocation syntax
- Integration: Can be referenced in agents.md or triggered directly by CEO

**Agent Manifest:**
- Purpose: Declarative specification of capabilities, constraints, and routing rules
- Examples: `backend-developer.yaml`, `code-reviewer.yaml`
- Pattern: YAML file validated against `schemas/agent-manifest.schema.json`
- Structure: name, tools, dependencies, resources, constraints, provider configurations

## Entry Points

**CLI Entry Point:**
- Location: `scripts/worker/execute.sh`
- Triggers: GitHub issue assignment or CLI invocation
- Responsibilities: Parse arguments, acquire lock, determine execution phase, dispatch to skill

**CEO Interface Entry Point:**
- Location: `.claude/skills/ceo-dashboard/SKILL.md` and `scripts/ceo/dashboard.sh`
- Triggers: CEO dashboard request or portfolio visibility query
- Responsibilities: Aggregate workspace status, render ANSI dashboard, display pending approvals

**Workspace Discovery Entry Point:**
- Location: `scripts/workspace/`
- Triggers: Initialization, dispatch routing, trust validation
- Responsibilities: Parse git submodules, validate workspace health, resolve workspace names

**Planning Entry Point:**
- Location: `.planning/phases/` phase directories
- Triggers: Phase initialization, human review request
- Responsibilities: RESEARCH → PLAN progression, context preservation, handoff documentation

## Error Handling

**Strategy:** Fail-safe with explicit state preservation. Errors do not lose state; recovery is always possible through rerun or manual intervention.

**Patterns:**

- **Lock Mechanism**: Prevents concurrent execution; stale locks detected and can be force-overridden with `--force` flag
- **Partial Completion**: If execution halts mid-phase, `worker:partial` label preserves state for resume
- **Approval Timeouts**: Stale approvals (> 24 hours) generate warning in CEO dashboard; can be manually confirmed
- **Workspace Health**: RED status workspaces block dispatch without CEO confirmation; YELLOW shows warnings
- **Trust Violations**: Exceed threshold triggers demotion; audit log captures violation context and remediation
- **Audit Trail**: Every failure recorded with timestamp, rationale, and recovery suggestion in `.worker/audit/chain.json`

## Cross-Cutting Concerns

**Logging:**
- `logger.sh` library provides structured logging with timestamps
- All worker operations log to `.worker/logs/` with ISO8601 timestamps
- CEO dashboard queries `.worker/briefings/` for aggregated status

**Validation:**
- YAML agent manifests validated against JSON Schema via `validator.sh`
- GitHub issue body parsed and validated for required fields (Summary, Acceptance Criteria)
- Workspace health checked before dispatch via `trust-validation.sh`
- Trust ceiling enforced at execution time; exceeding threshold blocks dispatch

**Authentication:**
- GitHub API authenticated via `GITHUB_TOKEN` environment variable
- No direct auth in Manifest codebase; delegates to GitHub and Anti-Gravity Agent Manager
- Workspace-level trust tracked independently via trust-ledger.md in each workspace

**Trust & Authorization:**
- Default trust level: 2 (Limited Autonomy per `.worker/config.json`)
- Guardrails enabled with violation thresholds: warning (20), probation (40), demotion (60)
- Trust ceiling inheritance: child workspaces capped by parent; enforced in `trust-validation.sh`
- Decay rate: violations decay at 5 points per day (per `.worker/config.json`)

---

*Architecture analysis: 2026-01-31*

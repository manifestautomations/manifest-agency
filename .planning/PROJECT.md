# PROJECT: Manifest Automations

## What This Is

An AI-powered development agency where the human operates as CEO — providing vision, decisions, and course-correction while autonomous agents handle coordination and execution. The agency orchestrates multiple projects through a hierarchy of Gemini orchestrators dispatching work to GSD-enabled Claude workers.

## Core Value

**The ONE thing that must work:** A complete loop where the CEO dispatches intent, an orchestrator routes it to workers, Claude executes via GSD, and results land in GitHub with clear status reporting back to the CEO's inbox.

## Vision

Wake up, brew coffee, check the inbox. The inbox is Mission Control in Anti-Gravity — status reports accumulated overnight from orchestrator agents. Review reports, issue high-level directives. Orchestrators take intent and dispatch to Claude workers. Workers spin up sub-agents for parallelization when needed.

Not writing code line by line. Not context-switching between terminals. Walking the floor, checking in on teams, making decisions, pointing in the right direction. Leverage AI the way a CEO leverages an organization.

## Current State

**v1.0 MVP shipped** (2026-01-29)

- 7 phases, 36 plans executed
- ~41,725 lines of code (shell, markdown, JSON, YAML)
- Complete CEO → Orchestrator → Worker → GitHub → Inbox loop functional
- Trust guardrails with audit chain operational
- Sub-agent parallelization available

**Tech stack:** Bash (worker scripts), Gemini (orchestration), Claude (execution), GitHub (coordination), GSD (framework)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  CEO (Human)                                            │
│  └─ Anti-Gravity Mission Control (inbox/briefings)      │
├─────────────────────────────────────────────────────────┤
│  GEMINI ORCHESTRATORS                                   │
│  └─ Model: Flash (fast), Pro (complex), Deep Think      │
│  └─ Dispatch via: claude-code --prompt --skill          │
│  └─ Cross-surface terminal control                      │
├─────────────────────────────────────────────────────────┤
│  GITHUB (coordination layer)                            │
│  └─ Issues = work items                                 │
│  └─ Projects = kanban state                             │
│  └─ PRs = completions                                   │
│  └─ Single source of truth                              │
├─────────────────────────────────────────────────────────┤
│  CLAUDE WORKERS (GSD-enabled)                           │
│  └─ Execute skills and commands                         │
│  └─ Report via gh CLI                                   │
│  └─ Spawn sub-agents for parallelization                │
├─────────────────────────────────────────────────────────┤
│  SUB-AGENTS                                             │
│  └─ Scoped to specific subtasks                         │
│  └─ Tightest constraints                                │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### Agent Definitions

Declarative YAML manifests in `automations/agents/{name}.yaml`:

```yaml
name: code-reviewer
model: gemini-2.0-flash
tools:
  - gh_cli
  - file_read
description: Reviews PRs for style compliance and logic errors
triggers:
  - workflow: pr-review
  - skill: quick-audit
```

Model selection encoded at design time, not runtime. CEO invokes intent (workflows/skills), agent definitions encode which model fits.

### Dispatch Mechanism

Orchestrators invoke Claude workers via cross-surface terminal control:

```bash
claude-code --prompt "Implement auth module per spec" \
            --skill "@/agents/skills/backend-service" \
            --context "issue:GH-142"
```

### GitHub Integration

Agents interact via gh CLI:

```bash
# Orchestrator assigns work
gh issue edit 142 --add-assignee "claude-worker-01" --project-status "In Progress"

# Worker completes
gh pr create --title "feat: auth module" --body "Closes #142"
gh issue close 142 --reason completed
```

### Trust System

Hook-enforced guardrails with hash-chained audit trail:

**Pre-hooks:** Command sanitization, scope validation, resource limits, 11 safety floor patterns
**Post-hooks:** Output validation, audit logging, escalation triggers

Trust flows down hierarchy with decreasing scope. Orchestrators can spawn; workers execute; sub-agents stay in lane.

### Project Structure

- **Agency root** contains project repos as **git submodules**
- **Worktrees** are **dynamic** — created per task, cleanup depends on outcome
  - Success → auto-cleanup after PR merged
  - Failure → preserve for debugging

### CEO Inbox

Comprehensive daily briefing via Anti-Gravity Mission Control:
- Blockers and escalations (priority)
- Overnight activity summary
- System health metrics
- Progress tracking
- Tomorrow's outlook

## Constraints

- Anti-Gravity as primary interface (Gemini orchestration layer)
- GitHub as single source of truth (no proprietary state management)
- GSD as execution layer for Claude workers
- Hook-based trust enforcement (not runtime permissions)
- Agents are disposable — hire when needed, sunset when project closes

## Reference Material

- [taches-cc-resources](https://github.com/glittercowboy/taches-cc-resources) — patterns for agent coordination
- [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) — skill library
- [get-shit-done](https://github.com/glittercowboy/get-shit-done) — GSD execution layer

## Requirements

### Validated

- ✓ GSD operational for Claude workers — v1.0
- ✓ GitHub configured as coordination layer (issues, projects, PRs) — v1.0
- ✓ One Gemini orchestrator that can dispatch to GSD and report back — v1.0
- ✓ Basic agent manifest structure (YAML definitions) — v1.0
- ✓ Pre/post hooks for trust guardrails — v1.0
- ✓ Dynamic worktree management — v1.0
- ✓ CEO inbox reporting (daily briefing format) — v1.0
- ✓ Worker sub-agent parallelization — v1.0
- ✓ Approval workflow for high-stakes actions — v1.0

### Active

- [ ] Multiple agent personas (specialists vs generalists)
- [ ] Workflow templates for repeatable patterns

### Out of Scope

- Custom dashboard (using Anti-Gravity Mission Control instead)
- Proprietary state management (GitHub is the source of truth)
- Runtime permission systems (hooks enforce trust, not runtime checks)
- Progressive trust levels 0-4 with earned autonomy (deferred to v2)
- Distributed tracing and cost tracking (deferred to v2)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| GitHub as coordination layer | Auditable, human-readable, no proprietary state | ✓ Good — 17 scripts, full lifecycle |
| Hook-based trust | Enforcement at execution boundaries, not runtime | ✓ Good — audit chain functional |
| Declarative agent definitions | CEO invokes intent, agents encode implementation | ✓ Good — YAML schema validated |
| Dynamic worktrees | Isolation without merge conflicts, outcome-based cleanup | ✓ Good — scripts operational |
| Agents as disposable resources | Scale to work, not the other way around | — Pending real-world validation |
| Label-based state machine | Survives crashes, human-visible in GitHub UI | ✓ Good — 6 worker states |
| Exit-and-resume for approvals | No polling, clean shell exits | ✓ Good — reaction-based continuation |
| Hash-chained audit trail | Tamper detection for compliance | ✓ Good — SHA-256 chaining |
| Tiered notification delivery | Immediate/delayed/silent based on urgency | ✓ Good — inbox integration |

---
*Last updated: 2026-01-29 after v1.0 milestone*

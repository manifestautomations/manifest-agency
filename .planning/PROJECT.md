# PROJECT: Manifest Automations

## What This Is

An AI-powered development agency where the human operates as CEO — providing vision, decisions, and course-correction while autonomous agents handle coordination and execution. The agency orchestrates multiple projects through Gemini orchestrators dispatching work to GSD-enabled Claude workers, with unified visibility through Anti-Gravity Agent Manager.

## Core Value

**The ONE thing that must work:** A complete loop where the CEO dispatches intent through Agent Manager, orchestrators route it to workspaces, Claude executes via GSD, and results land in GitHub with clear status reporting back to the CEO's unified inbox.

## Vision

Wake up, brew coffee, check the inbox. The inbox is Mission Control in Anti-Gravity — status reports accumulated overnight from orchestrator agents across all managed workspaces. Review reports, issue high-level directives. Orchestrators take intent and dispatch to Claude workers. Workers spin up sub-agents for parallelization when needed.

Not writing code line by line. Not context-switching between terminals. Walking the floor, checking in on teams, making decisions, pointing in the right direction. Leverage AI the way a CEO leverages an organization.

## Current State

**v1.1 Multi-Workspace Orchestration shipped** (2026-01-31)

- 12 phases, 49 plans executed across 2 milestones
- ~54,914 lines of code (shell scripts, markdown, JSON, YAML)
- Complete CEO → Orchestrator → Worker → GitHub → Inbox loop functional
- Multi-workspace orchestration through Agent Manager
- Trust guardrails with audit chain operational
- Cross-workspace dispatch with approval gates

**Tech stack:** Bash (worker scripts), Gemini (orchestration), Claude (execution), GitHub (coordination), GSD (framework), Anti-Gravity (CEO interface)

## Architecture

```
+-------------------------------------------------------------+
|  CEO (Human)                                                |
|  └─ Anti-Gravity Agent Manager (inbox/briefings/dispatch)   |
+-------------------------------------------------------------+
|  GEMINI ORCHESTRATORS                                       |
|  └─ Model: Flash (fast), Pro (complex), Deep Think          |
|  └─ Context: agents.md (core) + skills (explicit commands)  |
|  └─ Dispatch via: claude-code --prompt --skill              |
+-------------------------------------------------------------+
|  WORKSPACE LAYER                                            |
|  └─ Registry: git submodules                                |
|  └─ Health: GREEN/YELLOW/RED status                         |
|  └─ Frecency: time-decay scoring for suggestions            |
|  └─ Trust: ceiling inheritance, approval gates              |
+-------------------------------------------------------------+
|  GITHUB (coordination layer)                                |
|  └─ Issues = work items                                     |
|  └─ Projects = kanban state                                 |
|  └─ PRs = completions                                       |
|  └─ Single source of truth                                  |
+-------------------------------------------------------------+
|  CLAUDE WORKERS (GSD-enabled)                               |
|  └─ Execute skills and commands                             |
|  └─ Report via gh CLI                                       |
|  └─ Spawn sub-agents for parallelization                    |
+-------------------------------------------------------------+
|  SUB-AGENTS                                                 |
|  └─ Scoped to specific subtasks                             |
|  └─ Tightest constraints                                    |
+-------------------------------------------------------------+
```

## Constraints

- Anti-Gravity as primary interface (Gemini orchestration layer)
- GitHub as single source of truth (no proprietary state management)
- GSD as execution layer for Claude workers
- Hook-based trust enforcement (not runtime permissions)
- Agents are disposable — hire when needed, sunset when project closes
- Trust ceiling inheritance (child ≤ parent)

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
- ✓ Workspace registry with git submodule discovery — v1.1
- ✓ Workspace health checks (GREEN/YELLOW/RED) — v1.1
- ✓ Single-command workspace bootstrap — v1.1
- ✓ Cross-workspace dispatch by name — v1.1
- ✓ Frecency-based workspace suggestions — v1.1
- ✓ Portfolio dashboard with health indicators — v1.1
- ✓ Multi-project daily briefing — v1.1
- ✓ Trust ceiling enforcement — v1.1
- ✓ Cross-workspace approval gates — v1.1
- ✓ Anti-Gravity Agent Manager integration — v1.1

### Active

(None — start `/gsd:new-milestone` to define next milestone requirements)

### Out of Scope

- Custom dashboard (using Anti-Gravity Mission Control instead)
- Proprietary state management (GitHub is the source of truth)
- Runtime permission systems (hooks enforce trust, not runtime checks)
- Progressive trust levels 0-4 with earned autonomy (deferred to v2)
- Distributed tracing and cost tracking (deferred to v2)
- Centralized workspace state (keep per-project `.worker/`)
- Cross-project agent sharing (agents accumulate project-specific context)
- Global trust scores (different projects have different risk profiles)
- Real-time cross-project sync (on-demand aggregation sufficient)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| GitHub as coordination layer | Auditable, human-readable, no proprietary state | ✓ Good — 17 scripts, full lifecycle |
| Hook-based trust | Enforcement at execution boundaries, not runtime | ✓ Good — audit chain functional |
| Declarative agent definitions | CEO invokes intent, agents encode implementation | ✓ Good — YAML schema validated |
| Dynamic worktrees | Isolation without merge conflicts, outcome-based cleanup | ✓ Good — scripts operational |
| Label-based state machine | Survives crashes, human-visible in GitHub UI | ✓ Good — 6 worker states |
| Exit-and-resume for approvals | No polling, clean shell exits | ✓ Good — reaction-based continuation |
| Hash-chained audit trail | Tamper detection for compliance | ✓ Good — SHA-256 chaining |
| Tiered notification delivery | Immediate/delayed/silent based on urgency | ✓ Good — inbox integration |
| Git submodule workspace discovery | Stable API, no custom config | ✓ Good — v1.1 validated |
| Three-tier health status | GREEN/YELLOW/RED covers all states | ✓ Good — dashboard uses it |
| Trust ceiling inheritance | Child ≤ parent prevents escalation | ✓ Good — enforced at dispatch |
| Frecency for suggestions | Time-decay weights, intuitive defaults | ✓ Good — fuzzy matching works |
| Hybrid agents.md + skills | Core context + explicit commands (Vercel research) | ✓ Good — 56% non-invocation handled |

## Reference Material

- [taches-cc-resources](https://github.com/glittercowboy/taches-cc-resources) — patterns for agent coordination
- [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) — skill library
- [get-shit-done](https://github.com/glittercowboy/get-shit-done) — GSD execution layer

---
*Last updated: 2026-01-31 after v1.1 milestone*

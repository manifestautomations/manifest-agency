# Requirements: Manifest Automations AI Agency

**Version:** 1.0 (MVP)
**Created:** 2026-01-26
**Core Value:** Complete loop where CEO dispatches intent, orchestrator routes, Claude executes, results land in GitHub with status reporting back.

---

## v1 Requirements

### Foundation

- [x] **FOUND-01**: Repository configured with git submodules for multi-project structure
- [x] **FOUND-02**: Agent manifest schema defined in YAML format with model, tools, triggers, constraints
- [x] **FOUND-03**: Directory structure established (.claude/commands/, .claude/skills/, .claude/agents/, .planning/, projects/, templates/)
- [x] **FOUND-04**: Dynamic worktree management — auto-create worktrees per task, cleanup based on outcome (success = remove, failure = preserve)

### Orchestration

- [ ] **ORCH-01**: Single Gemini orchestrator can dispatch work to Claude workers
- [ ] **ORCH-02**: Orchestrator decomposes high-level CEO intent into discrete subtasks
- [ ] **ORCH-03**: Cross-surface terminal control — orchestrator invokes `claude-code --prompt --skill --context` via terminal
- [ ] **ORCH-04**: Model selection encoded in agent manifests (Flash for fast routing, Pro for complex reasoning, Deep Think for architecture)

### Worker Execution

- [ ] **WORK-01**: Claude worker executes commands and skills via GSD framework
- [ ] **WORK-02**: Worker reports status and results via gh CLI (issue updates, PR creation)
- [ ] **WORK-03**: Worker can spawn sub-agents for parallelization of independent subtasks
- [ ] **WORK-04**: Each worker operates in isolated git worktree to prevent conflicts

### GitHub Coordination

- [x] **GH-01**: GitHub issues serve as work items (task assignment, status tracking, context storage)
- [x] **GH-02**: Pull requests represent completed work (code changes linked to issues)
- [x] **GH-03**: GitHub Projects provide kanban-style state visualization
- [x] **GH-04**: GitHub is single source of truth — no proprietary state management, all coordination via gh CLI

### Trust & Guardrails

- [x] **TRUST-01**: Pre-hooks enforce command sanitization (block destructive operations, validate scope)
- [x] **TRUST-02**: Post-hooks validate outputs and log actions for audit trail
- [x] **TRUST-03**: Basic access control — agents have defined scope boundaries per manifest

### Observability

- [ ] **OBS-01**: Structured logging (JSON format) for all agent actions and decisions
- [ ] **OBS-02**: Error tracking captures agent failures with full context for debugging

### CEO Interface

- [ ] **CEO-01**: Status visibility — CEO can see what agents are doing and their results
- [ ] **CEO-02**: Decision points — approval gates for high-stakes actions requiring human judgment
- [ ] **CEO-03**: Anti-Gravity Mission Control serves as primary inbox interface
- [ ] **CEO-04**: Daily briefings aggregate completions, in-progress items, blockers, and escalations

---

## v2 Requirements (Deferred)

### Trust & Guardrails

- [ ] **TRUST-04**: Comprehensive audit logging with immutable trail
- [ ] **TRUST-05**: Progressive trust levels (0-4) with earned autonomy model
- [ ] **TRUST-06**: Automatic trust promotion/demotion based on performance metrics

### Observability

- [ ] **OBS-03**: Distributed tracing across agent boundaries (OpenTelemetry)
- [ ] **OBS-04**: Cost tracking per agent, per operation, per feature
- [ ] **OBS-05**: LangSmith integration for production observability

### Scale

- [ ] **SCALE-01**: Multiple orchestrators (per-domain or hierarchical)
- [ ] **SCALE-02**: Agent marketplace for pre-built specialists
- [ ] **SCALE-03**: Semantic caching to reduce token costs

---

## Out of Scope

| Exclusion | Reason |
|-----------|--------|
| Custom dashboard UI | Using Anti-Gravity Mission Control |
| Proprietary state database | GitHub is single source of truth |
| Runtime permission system | Hook-based enforcement is simpler and more reliable |
| Multi-model orchestration (OpenAI, etc.) | Start with Gemini/Claude, add diversity later |
| Enterprise SSO/RBAC | Not needed for single-user agency |

---

## Traceability

*Populated by roadmapper*

| REQ-ID | Phase | Status |
|--------|-------|--------|
| FOUND-01 | Phase 1 | Complete |
| FOUND-02 | Phase 1 | Complete |
| FOUND-03 | Phase 1 | Complete |
| FOUND-04 | Phase 1 | Complete |
| GH-01 | Phase 2 | Complete |
| GH-02 | Phase 2 | Complete |
| GH-03 | Phase 2 | Complete |
| GH-04 | Phase 2 | Complete |
| WORK-01 | Phase 3 | Complete |
| WORK-02 | Phase 3 | Complete |
| WORK-04 | Phase 3 | Complete |
| OBS-01 | Phase 3 | Complete |
| OBS-02 | Phase 3 | Complete |
| TRUST-01 | Phase 4 | Complete |
| TRUST-02 | Phase 4 | Complete |
| TRUST-03 | Phase 4 | Complete |
| ORCH-01 | Phase 5 | Pending |
| ORCH-02 | Phase 5 | Pending |
| ORCH-03 | Phase 5 | Pending |
| ORCH-04 | Phase 5 | Pending |
| WORK-03 | Phase 6 | Pending |
| CEO-01 | Phase 7 | Pending |
| CEO-02 | Phase 7 | Pending |
| CEO-03 | Phase 7 | Pending |
| CEO-04 | Phase 7 | Pending |

---

*Last updated: 2026-01-28*

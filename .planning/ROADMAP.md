# Roadmap: Manifest Automations

## Overview

Build an AI-powered development agency where the CEO dispatches intent, Gemini orchestrators route work, Claude workers execute via GSD, and results land in GitHub with status reporting back to Mission Control. The journey starts with foundational structure, progresses through single-worker validation, adds trust guardrails, introduces orchestration, and culminates in a complete CEO-to-worker loop with parallelization capabilities.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Establish repository structure, agent manifests, and worktree management
- [x] **Phase 2: GitHub Coordination** - Configure GitHub as single source of truth for all work tracking
- [x] **Phase 3: Single Worker** - Validate one Claude worker can execute and report via GSD
- [x] **Phase 4: Trust Guardrails** - Implement hook-based trust enforcement and audit logging
- [ ] **Phase 5: Orchestration** - Add Gemini orchestrator to dispatch work and aggregate status
- [ ] **Phase 6: Worker Parallelization** - Enable workers to spawn sub-agents for parallel execution
- [ ] **Phase 7: CEO Interface** - Complete loop with Mission Control integration and daily briefings

## Phase Details

### Phase 1: Foundation
**Goal**: Repository and agent infrastructure ready for multi-project orchestration
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04
**Success Criteria** (what must be TRUE):
  1. Repository has working git submodule structure for multiple projects
  2. Agent manifest schema (YAML) is defined with model, tools, triggers, constraints
  3. Directory structure exists with all required folders (.claude/, .planning/, projects/, templates/)
  4. Worktrees can be created automatically per task and cleaned up based on outcome
**Plans**: 3 plans in 2 waves

Plans:
- [x] 01-01-PLAN.md - Directory structure and git submodule configuration (FOUND-01, FOUND-03)
- [x] 01-02-PLAN.md - Agent manifest JSON Schema and example agents (FOUND-02)
- [x] 01-03-PLAN.md - Worktree automation scripts (FOUND-04)

### Phase 2: GitHub Coordination
**Goal**: GitHub configured as authoritative coordination layer for all agent work
**Depends on**: Phase 1
**Requirements**: GH-01, GH-02, GH-03, GH-04
**Success Criteria** (what must be TRUE):
  1. GitHub issues serve as work items with assignment and status tracking
  2. Pull requests link to issues and represent completed work
  3. GitHub Project board visualizes work state across all agents
  4. All agent coordination happens via gh CLI with no proprietary state storage
**Plans**: 5 plans in 4 waves

Plans:
- [x] 02-01-PLAN.md - Prerequisites: jq installation, cache setup, templates (GH-04)
- [x] 02-02-PLAN.md - GitHub Project board setup with custom fields and views (GH-03)
- [x] 02-03-PLAN.md - Issue management scripts: create, claim, status, comment (GH-01)
- [x] 02-04-PLAN.md - PR creation and project query scripts (GH-02, GH-04)
- [x] 02-05-PLAN.md - GitHub Actions workflow and documentation (GH-03)

### Phase 3: Single Worker
**Goal**: One Claude worker can execute commands, report results, and provide observability
**Depends on**: Phase 2
**Requirements**: WORK-01, WORK-02, WORK-04, OBS-01, OBS-02
**Success Criteria** (what must be TRUE):
  1. Claude worker executes commands and skills via GSD framework
  2. Worker updates GitHub issues and creates PRs via gh CLI
  3. Worker operates in isolated git worktree without conflicts
  4. All worker actions logged in structured JSON format
  5. Worker failures captured with full context for debugging
**Plans**: 4 plans in 4 waves

Plans:
- [x] 03-01-PLAN.md - Worker infrastructure: .worker/ directory, config, gitignore (OBS-01)
- [x] 03-02-PLAN.md - Core libraries: logger.sh, lock.sh, parser.sh (OBS-01, OBS-02)
- [x] 03-03-PLAN.md - Worker execution skill with state machine and approval flow (WORK-01, WORK-02, WORK-04)
- [x] 03-04-PLAN.md - Comment templates, documentation, and end-to-end verification (WORK-02)

### Phase 4: Trust Guardrails
**Goal**: Hook-based trust enforcement prevents destructive operations and maintains audit trail
**Depends on**: Phase 3
**Requirements**: TRUST-01, TRUST-02, TRUST-03
**Success Criteria** (what must be TRUE):
  1. Pre-hooks block destructive commands and validate scope before execution
  2. Post-hooks validate outputs and log all actions to audit trail
  3. Agent manifests define scope boundaries that are enforced at execution time
**Plans**: 5 plans in 4 waves

Plans:
- [x] 04-01-PLAN.md - Trust guardrail YAML configuration and yq installation (TRUST-01)
- [x] 04-02-PLAN.md - Audit chain infrastructure with hash chaining (TRUST-02)
- [x] 04-03-PLAN.md - Validator library with command and scope validation (TRUST-01, TRUST-03)
- [x] 04-04-PLAN.md - Hooks library with pre/post execution wrapper (TRUST-01, TRUST-02)
- [x] 04-05-PLAN.md - Worker integration and documentation (TRUST-01, TRUST-02, TRUST-03)

### Phase 5: Orchestration
**Goal**: Gemini orchestrator can decompose CEO intent, dispatch to workers, and aggregate status
**Depends on**: Phase 4
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04
**Success Criteria** (what must be TRUE):
  1. Gemini orchestrator receives high-level intent and decomposes into discrete subtasks
  2. Orchestrator dispatches work to Claude workers via terminal command (scripts/worker/execute.sh)
  3. Model selection follows agent manifests (Flash/Pro/Deep Think)
  4. Orchestrator aggregates worker status and reports results
**Plans**: 6 plans in 3 waves

Plans:
- [ ] 05-01-PLAN.md - Gemini skill skeleton, intent classification, issue template (ORCH-02)
- [ ] 05-02-PLAN.md - Task decomposition and dependency graph helpers (ORCH-02)
- [ ] 05-03-PLAN.md - Worker dispatch with dependency-aware parallel execution (ORCH-01, ORCH-03)
- [ ] 05-04-PLAN.md - Status aggregation with tiered output formats (ORCH-04)
- [ ] 05-05-PLAN.md - Complete Gemini skill and documentation (ORCH-01, ORCH-04)
- [ ] 05-06-PLAN.md - End-to-end verification checkpoint

### Phase 6: Worker Parallelization
**Goal**: Workers can spawn sub-agents to parallelize independent subtasks
**Depends on**: Phase 5
**Requirements**: WORK-03
**Success Criteria** (what must be TRUE):
  1. Worker identifies independent subtasks suitable for parallelization
  2. Worker spawns sub-agents with scoped constraints
  3. Sub-agents execute in parallel and report completion
  4. Worker aggregates sub-agent results into cohesive deliverable
**Plans**: TBD

Plans:
- [ ] 06-01: TBD during plan-phase

### Phase 7: CEO Interface
**Goal**: Complete CEO loop with Mission Control inbox integration and automated daily briefings
**Depends on**: Phase 6
**Requirements**: CEO-01, CEO-02, CEO-03, CEO-04
**Success Criteria** (what must be TRUE):
  1. CEO can see real-time status of all agent activities and results
  2. High-stakes actions have approval gates requiring CEO judgment
  3. Anti-Gravity Mission Control serves as primary inbox for agent communication
  4. Daily briefings automatically aggregate completions, in-progress work, blockers, and escalations
**Plans**: TBD

Plans:
- [ ] 07-01: TBD during plan-phase

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2026-01-27 |
| 2. GitHub Coordination | 5/5 | Complete | 2026-01-27 |
| 3. Single Worker | 4/4 | Complete | 2026-01-27 |
| 4. Trust Guardrails | 5/5 | Complete | 2026-01-28 |
| 5. Orchestration | 0/6 | Not started | - |
| 6. Worker Parallelization | 0/TBD | Not started | - |
| 7. CEO Interface | 0/TBD | Not started | - |

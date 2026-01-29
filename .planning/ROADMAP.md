# Roadmap: Manifest Automations

## Milestones

- v1.0 MVP - Phases 1-7 (shipped 2026-01-29)
- v1.1 Multi-Workspace Orchestration - Phases 8-12 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-7) - SHIPPED 2026-01-29</summary>

See `.planning/MILESTONES.md` for v1.0 details.

7 phases, 36 plans completed. Delivered complete CEO-to-worker loop with trust guardrails, GitHub coordination, and inbox reporting.

</details>

### v1.1 Multi-Workspace Orchestration (In Progress)

**Milestone Goal:** Enable a real workday managing 2-3 repos through Anti-Gravity Agent Manager with unified visibility and cross-workspace dispatch.

#### Phase 8: Workspace Foundation
**Goal**: Establish workspace registry and isolation boundaries before any cross-workspace execution
**Depends on**: Phase 7 (v1.0 complete)
**Requirements**: WKSP-01, WKSP-02, WKSP-03, WKSP-04
**Success Criteria** (what must be TRUE):
  1. CEO can list all registered workspaces and their health status
  2. New project can be bootstrapped as managed workspace via single command
  3. Each workspace maintains its own trust ledger (scores isolated between projects)
  4. Invalid workspace registration fails with clear error message
**Plans**: 3 plans in 3 waves

Plans:
- [ ] 08-01-PLAN.md - Workspace discovery and name resolution (Wave 1)
- [ ] 08-02-PLAN.md - Workspace health and validation (Wave 2)
- [ ] 08-03-PLAN.md - Workspace bootstrap with trust isolation (Wave 3)

#### Phase 9: Cross-Workspace Dispatch
**Goal**: CEO can dispatch work to any registered workspace by name
**Depends on**: Phase 8
**Requirements**: DISP-01, DISP-02
**Success Criteria** (what must be TRUE):
  1. CEO can say "do X in Project Y" and work routes to correct workspace
  2. Workspace name/alias resolves to correct filesystem path
  3. Dispatch fails gracefully if workspace not found or unhealthy
**Plans**: TBD

Plans:
- [ ] 09-01: Workspace name resolution and path mapping
- [ ] 09-02: Dispatch routing with workspace targeting

#### Phase 10: Portfolio Visibility
**Goal**: CEO sees unified status across all managed projects in one view
**Depends on**: Phase 8 (can execute in parallel with Phase 9)
**Requirements**: VIEW-01, VIEW-02, VIEW-03, VIEW-04
**Success Criteria** (what must be TRUE):
  1. CEO can view aggregated status showing all projects in single dashboard
  2. Each project shows health indicator (green/yellow/red) at a glance
  3. Daily briefing covers all projects with per-project sections
  4. Inbox notifications are tagged with originating project
**Plans**: TBD

Plans:
- [ ] 10-01: Status aggregation across workspaces
- [ ] 10-02: Health indicators and dashboard view
- [ ] 10-03: Multi-project briefing generation
- [ ] 10-04: Inbox aggregation with project tags

#### Phase 11: Trust & Approval Gates
**Goal**: Cross-workspace operations are properly constrained and approved
**Depends on**: Phase 8, Phase 9
**Requirements**: TRST-01, TRST-02, TRST-03
**Success Criteria** (what must be TRUE):
  1. Child workspace trust cannot exceed parent agency ceiling
  2. Each workspace trust ledger operates independently (verified across dispatch)
  3. Cross-workspace operations prompt for explicit CEO approval
**Plans**: TBD

Plans:
- [ ] 11-01: Trust ceiling inheritance enforcement
- [ ] 11-02: Cross-workspace approval workflow

#### Phase 12: Anti-Gravity Integration
**Goal**: System operates through Anti-Gravity Agent Manager as primary CEO interface
**Depends on**: Phase 8, Phase 9, Phase 10, Phase 11
**Requirements**: INTG-01
**Success Criteria** (what must be TRUE):
  1. CEO can manage all workspaces through Agent Manager (not terminal)
  2. All v1.1 features accessible via Agent Manager skills
  3. End-to-end flow works: dispatch in Agent Manager, results in unified inbox
**Plans**: TBD

Plans:
- [ ] 12-01: Agent Manager skill adaptation
- [ ] 12-02: End-to-end integration validation

## Progress

**Execution Order:**
Phases execute in numeric order: 8 -> 9 -> 10 -> 11 -> 12
(Phase 10 can parallel with 9 after 8 completes)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 8. Workspace Foundation | v1.1 | 0/3 | Planned | - |
| 9. Cross-Workspace Dispatch | v1.1 | 0/2 | Not started | - |
| 10. Portfolio Visibility | v1.1 | 0/4 | Not started | - |
| 11. Trust & Approval Gates | v1.1 | 0/2 | Not started | - |
| 12. Anti-Gravity Integration | v1.1 | 0/2 | Not started | - |

**Coverage:** 14/14 requirements mapped

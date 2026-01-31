# Requirements: Manifest Automations v1.1

**Defined:** 2026-01-29
**Core Value:** Complete loop where CEO dispatches intent, orchestrator routes, Claude executes, results land in GitHub with status reporting back — now across multiple repos.

## v1.1 Requirements

Requirements for multi-workspace orchestration. Each maps to roadmap phases.

### Workspace Foundation

- [x] **WKSP-01**: Agency can register child workspaces via config file
- [x] **WKSP-02**: Each workspace has isolated trust ledger (scores don't leak between projects)
- [x] **WKSP-03**: CEO can bootstrap new project as managed workspace via script
- [x] **WKSP-04**: System validates registered workspace health (repo exists, GSD setup present)

### Cross-Workspace Dispatch

- [x] **DISP-01**: CEO can dispatch work to specific project by name ("do X in Project Y")
- [x] **DISP-02**: System resolves workspace names/aliases to paths

### Portfolio Visibility

- [x] **VIEW-01**: CEO can see status aggregated across all managed projects
- [x] **VIEW-02**: Dashboard shows health indicator (green/yellow/red) per project
- [x] **VIEW-03**: Daily briefing covers all projects in single document with sections
- [x] **VIEW-04**: Inbox aggregates notifications across projects with project tags

### Trust & Approval

- [x] **TRST-01**: Child workspace trust is constrained by parent ceiling
- [x] **TRST-02**: Each workspace maintains separate trust ledger
- [x] **TRST-03**: Cross-workspace operations require explicit approval

### Integration

- [x] **INTG-01**: System works through Anti-Gravity Agent Manager as primary interface

## v2 Requirements

Deferred to future milestone. Tracked but not in current roadmap.

### Advanced Dispatch

- **DISP-03**: Local dispatch mode via cd && execute (submodules on same machine)
- **DISP-04**: Cross-project dependency awareness (detect `Blocked by repo#N`)
- **DISP-05**: Resource-aware dispatch (prevent over-allocation across projects)

### Production Infrastructure

- **PROD-01**: Remote dispatch via GitHub repository_dispatch events
- **PROD-02**: Correlation IDs for tracing operations across workspaces
- **PROD-03**: Async completion detection for remote operations

### Portfolio Analytics

- **ANLYT-01**: Portfolio-level velocity metrics (agency-wide temporal compression)
- **ANLYT-02**: Cross-workspace search (find implementations across repos)
- **ANLYT-03**: Workspace health trends over time

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Centralized workspace state | Keep per-project `.worker/` — no shared database |
| Cross-project agent sharing | Agents accumulate project-specific context; sharing causes contamination |
| Global trust scores | Different projects have different risk profiles; keep isolated |
| Real-time cross-project sync | On-demand aggregation sufficient for 2-3 projects; adds complexity |
| Template propagation across workspaces | Complex sync; validate manual pattern first |
| Project grouping/portfolios | 2-3 projects don't need grouping yet |
| Smart routing based on project state | Complex heuristics; CEO explicit routing first |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| WKSP-01 | Phase 8 | Complete |
| WKSP-02 | Phase 8 | Complete |
| WKSP-03 | Phase 8 | Complete |
| WKSP-04 | Phase 8 | Complete |
| DISP-01 | Phase 9 | Complete |
| DISP-02 | Phase 9 | Complete |
| VIEW-01 | Phase 10 | Complete |
| VIEW-02 | Phase 10 | Complete |
| VIEW-03 | Phase 10 | Complete |
| VIEW-04 | Phase 10 | Complete |
| TRST-01 | Phase 11 | Complete |
| TRST-02 | Phase 11 | Complete |
| TRST-03 | Phase 11 | Complete |
| INTG-01 | Phase 12 | Complete |

**Coverage:**
- v1.1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-01-29*
*Last updated: 2026-01-30 after Phase 11 completion*

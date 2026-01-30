# Phase 10: Portfolio Visibility - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

CEO sees unified status across all managed projects in one view. Aggregated dashboard, health indicators, multi-project briefings, and project-tagged inbox notifications. Dispatch and trust enforcement are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Dashboard layout
- Claude decides arrangement (list vs cards) based on terminal output constraints
- Standard info per project: name, health status, last activity, pending items count
- Sorted by activity (frecency-style) — most recently active first
- Prominent "Needs Attention" section at top with actionable items across all projects

### Health indicators
- GREEN: Healthy workspace, recent activity
- YELLOW: Stale activity (no activity for 3+ days)
- RED: Trust violations OR broken workspace state (health check fails)
- Cached with refresh — compute on workspace access, not every dashboard view

### Briefing structure
- Order: Blockers → Summary → Details
  1. Problems/blockers first (what needs immediate attention)
  2. Executive summary across all projects
  3. Per-project breakdown
- Projects with nothing to report: mention count only ("3 projects with no updates")
- On-demand generation only — CEO requests when wanted, no scheduled auto-generation

### Inbox tagging
- Project origin shown as prefix AND metadata: `[ProjectName] subject` + `project` field
- Interactive filtering — prompt to select which projects to show
- Aggregate counts at top: "Project A: 3 items, Project B: 1 item" before listing
- Prioritized by severity — critical/urgent items first regardless of project

### Claude's Discretion
- Exact dashboard layout (list vs cards vs table)
- Visual treatment of health colors in terminal
- Briefing formatting and markdown structure
- Interactive filter UI implementation

</decisions>

<specifics>
## Specific Ideas

- "Needs Attention" section should surface actionable items, not just status
- Briefing blockers-first mirrors how I want to consume information
- Project counts at top of inbox gives quick triage without scrolling

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-portfolio-visibility*
*Context gathered: 2026-01-29*

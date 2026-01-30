# Phase 9: Cross-Workspace Dispatch - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

CEO can dispatch work to any registered workspace by name or alias. Work routes to the correct workspace with proper context. Dispatch fails gracefully for invalid or unhealthy targets.

</domain>

<decisions>
## Implementation Decisions

### Targeting Syntax
- Workspace specified via ID or path from status reports (not parsed from natural language)
- Aliases preferred for readability, paths work as fallback
- Frecency-based defaults with contextual understanding — recent/frequent workspaces bubble up, conversation context informs selection

### Resolution Behavior
- Fuzzy matching with suggestions — no exact match shows closest options, CEO confirms
- Ambiguous matches (multiple workspaces) prefer frecency — auto-select most recent/frequent, show confirmation
- Unhealthy workspace: warn and confirm — CEO sees health issues, decides whether to proceed
- Unreachable workspace (path gone, permissions): error + offer to remove from registry

### Dispatch Handoff
- Trust: child workspace inherits dispatcher's trust ceiling
- Lineage: parent reference only (immediate context, not full chain)
- Audit: centralized dispatch log in orchestrator (not per-workspace)
- Metadata: rich context — task description, trust ceiling, parent reference, priority, deadline hints, related workspaces, CEO notes

### Claude's Discretion
- Exact frecency algorithm implementation
- Fuzzy matching threshold and algorithm
- Centralized log format and rotation
- Context extraction from conversation

</decisions>

<specifics>
## Specific Ideas

- Workspace identifiers visible in status reports — CEO sees them, uses them to target
- Context-aware: system should understand from conversation which workspace is being discussed

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-cross-workspace-dispatch*
*Context gathered: 2026-01-29*

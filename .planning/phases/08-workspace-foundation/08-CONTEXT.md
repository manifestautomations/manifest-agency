# Phase 8: Workspace Foundation - Context

**Gathered:** 2026-01-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish workspace registry and isolation boundaries before any cross-workspace execution. Workspaces are git submodules under the parent Manifest Automations repo. This phase sets up discovery, naming, health checks, and bootstrap — but does NOT implement cross-workspace dispatch or portfolio views.

</domain>

<decisions>
## Implementation Decisions

### Registry format
- Git submodules are the source of truth for workspace list
- No separate registry file needed — discover workspaces by scanning submodules
- Workspace-specific settings (trust ledger, any local config) live within each workspace
- Parent repo already knows all workspace paths via submodule configuration

### Naming & aliases
- Folder name (submodule directory name) always works as identifier
- Custom aliases can optionally be defined for shorter references
- Exact match only — no fuzzy/prefix matching
- If name doesn't match exactly, fail with suggestions of valid workspace names

### Claude's Discretion (Naming)
- Where to store aliases (parent config vs per-workspace)
- Case sensitivity behavior

### Health indicators
- Check health on-demand only (when CEO asks for status or before dispatch) — no background polling
- Unhealthy workspace blocks dispatch with clear explanation of what's wrong
- Daily briefing only mentions workspaces with health issues — green status is silent

### Claude's Discretion (Health)
- Specific health criteria (git state issues, trust issues, or combination)
- Red vs yellow severity thresholds

### Bootstrap experience
- New projects automatically become managed workspaces when created under parent repo
- New workspace inherits parent trust ceiling as starting point
- Validation required before accepting as workspace (must have required structure)
- If validation fails, offer to scaffold missing structure automatically

</decisions>

<specifics>
## Specific Ideas

- "This should be part of the new project setup, I shouldn't be running commands" — bootstrap is invisible, happens during project creation
- Submodules as source of truth means git already handles the registry
- Monorepo-style organization but each workspace is a separate repo (submodule)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-workspace-foundation*
*Context gathered: 2026-01-29*

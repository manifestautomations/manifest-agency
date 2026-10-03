# Phase 1: Foundation - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Repository and agent infrastructure ready for multi-project orchestration. This includes git submodule structure, agent manifest schema, directory structure, and worktree management. Does NOT include GitHub coordination, trust enforcement, or orchestration logic — those are later phases.

</domain>

<decisions>
## Implementation Decisions

### Agent Manifest Design
- Orchestrator decides model at dispatch time based on task complexity (no fixed model per agent)
- Constraints expressed as both allowlist and blocklist with sensible defaults
- Triggers are optional — agents can be invoked directly OR auto-triggered by events
- Metadata follows layered approach:
  - **Universal base:** name, version, author, description, dependencies, resource requirements, execution context, routing hints
  - **Provider-specific extensions:** Claude (skills, tool schemas), Gemini (function declarations, grounding), etc.
  - Internal terminology standardized with provider adapters for translation

### Worktree Lifecycle
- Orchestrator decides when to create worktrees (detects parallel work, keeps main clean)
- Worktrees are siblings to main repo (e.g., `../project-name-feature/`)
- Cleanup is outcome-based AND time-based:
  - PR merged → delete worktree
  - PR closed/rejected → archive or delete
  - Inactivity timeout as backup cleanup mechanism
- State tracked via orchestrator tooling (like Container Use's `list`, `watch`, `log` commands)
- Git branches remain source of truth for the work itself

### Multi-Project Organization
- Projects are git submodules with independent histories
- Projects inherit `.claude/` from parent Manifest Automations repo, can override locally
- Isolation boundary: agent can access project + shared resources from parent
- New projects created by orchestrator when CEO requests ("start new project X")
- All submodules live under `projects/` folder

### Directory Conventions
- `.claude/` at parent level: agency-wide agents, hooks, settings, commands, skills not in global GSD
- `.planning/` split: parent has agency state, projects have project-specific state
- `templates/` contains: new project scaffolding, agent manifest templates, documentation templates
- Project submodules: `projects/<project-name>/` with their own `.claude/` and `.planning/`

### Claude's Discretion
- Exact YAML schema for agent manifests
- Specific timeout durations for worktree cleanup
- Folder naming conventions for worktrees
- Template file structure details

</decisions>

<specifics>
## Specific Ideas

- Agent manifest metadata should map cleanly to provider-specific terminology (skills vs. tools vs. functions)
- Worktree observability should feel like Container Use: `list`, `watch`, `log` style commands
- Projects inherit from parent but can override — similar to class inheritance pattern

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-01-27*

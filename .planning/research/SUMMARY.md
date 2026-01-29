# Project Research Summary

**Project:** Manifest Automations v1.1 - Multi-Workspace Orchestration
**Domain:** Multi-repository AI agent orchestration for development agency
**Researched:** 2026-01-29
**Confidence:** MEDIUM-HIGH

## Executive Summary

Multi-workspace orchestration for v1.1 is achievable through Google Antigravity Agent Manager integration, which provides the core infrastructure (unified inbox, workspace dispatch, skills portability) that would otherwise require building from scratch. The critical insight from research: **you do not need to build cross-workspace communication infrastructure** -- Antigravity already provides it through `--include-directories` for multi-workspace file access and native Inbox aggregation. Your job is integration, not invention.

The recommended approach is a phased migration that preserves all v1.0 capabilities while layering multi-workspace features on top. Start with a workspace registry and local dispatch (Mode 1: cd && execute), then extend to status aggregation, trust inheritance, and finally remote dispatch via repository_dispatch events. The architecture extends the existing parent-child pattern from sub-agent parallelization: parent workspace orchestrates, child workspaces execute with inherited (but scoped) trust constraints.

The primary risks are context contamination between workspaces (agent leaks Project A context into Project B), submodule state drift (workers operate on stale code), and trust boundary leakage (agent retains high trust when switching to new workspace). All three require explicit isolation enforcement: hard context resets, per-workspace trust ledgers, and submodule automation scripts. Secondary risks include priority starvation (low-priority projects never progress), status aggregation staleness (decisions made on old data), and cross-project dependency cycles (deadlocks). The mitigation strategy: build isolation first (Foundation phase), then orchestration with dependency validation (Orchestration phase), then parallel execution with resource reservation (Execution phase).

## Key Findings

### Recommended Stack

Google Antigravity (released November 2025) is the centerpiece integration. It provides Agent Manager for multi-workspace dispatch, unified Inbox for notification aggregation, and native skills compatibility with existing `.claude/skills/`. The Gemini CLI supports `--include-directories` for cross-workspace file access within a single session.

**Core technologies:**
- **Google Antigravity**: Primary interface -- Agent Manager, unified Inbox, multi-workspace support. Free during preview.
- **Gemini CLI (v0.23+)**: Headless automation -- `--include-directories` for cross-workspace file context, skills execution.
- **`agy` CLI**: Terminal access to Antigravity -- bridges existing bash scripts without GUI.
- **Repository Dispatch (GitHub API)**: Cross-repo automation -- standard pattern for triggering workflows in child repos.

**What NOT to add:**
- No custom IPC/message queue (Antigravity handles inter-agent communication)
- No database for workspace state (Agent Manager persists this; `.worker/` sufficient for audit)
- No new notification system (Inbox provides this)
- No MCP server for cross-workspace (`--include-directories` solves this simpler)

**Stack confidence:** HIGH (Context7 + official documentation + community verification)

### Expected Features

**Must have (table stakes):**
- Cross-project status aggregation -- CEO needs single view across all repos
- Unified inbox across projects -- one notification stream with project tagging
- Project-scoped work dispatch -- "Create feature X in Project Y" routes correctly
- Aggregated daily briefing -- one briefing covering all projects
- Project health summary -- traffic light indicators (green/yellow/red) per project
- Workspace registration -- config file listing managed repos

**Should have (competitive):**
- Cross-project dependency awareness -- detect `Blocked by org/repo#N`
- Resource-aware dispatch -- don't over-allocate agents across projects
- Portfolio-level velocity -- agency-wide temporal compression metrics
- Per-project trust isolation -- trust scores stay project-local (already designed this way)
- Cross-workspace search -- find implementations across repos

**Defer (v2+):**
- Template propagation (complex sync, validate manual pattern first)
- Project grouping/portfolios (2-3 projects don't need grouping yet)
- Smart routing based on project state (complex heuristics)
- Real-time cross-project sync (expensive, on-demand sufficient)

**Feature confidence:** MEDIUM-HIGH (verified against portfolio management patterns, multi-repo tooling)

### Architecture Approach

The architecture extends v1.0 by introducing a workspace registry (`.planning/workspaces/registry.yaml`) and cross-workspace dispatch mechanism. Parent workspace (Manifest Automations) becomes orchestration hub; child workspaces (submodules or separate repos) maintain their own GSD setup while receiving dispatched work. Three dispatch modes available: (1) Local invocation for submodules on same machine, (2) Repository dispatch for remote repos, (3) Workflow dispatch for existing GH Actions.

**Major components:**
1. **Workspace Registry** -- tracks registered child workspaces with metadata (path, repo, trust level, capabilities)
2. **Cross-Workspace Dispatch** -- routes work to correct workspace via local cd or repository_dispatch
3. **Status Aggregator** -- polls child repos via `gh` CLI, generates portfolio view and unified briefing
4. **Trust Inheritance** -- parent ceiling with child-specific constraints (same pattern as sub-agent scoping)
5. **Workspace Bootstrap** -- script to register new child workspaces with validation

**Key decisions:**
- Registry location: `.planning/workspaces/registry.yaml` (consistent with existing `.planning/` pattern)
- Dispatch mechanism: Local mode first, repository_dispatch for production
- Status aggregation: Polling via gh CLI (stateless, no webhook infrastructure)
- Trust model: Parent ceiling, per-workspace trust ledgers

**Architecture confidence:** MEDIUM-HIGH (based on v1.0 codebase analysis + industry patterns)

### Critical Pitfalls

Top 5 pitfalls that could derail v1.1:

1. **Context Contamination** -- Workers leak Project A context (paths, conventions, secrets) into Project B.
   - **Avoid:** Hard context reset between workspace switches, workspace ID in every prompt/tool call, no shared memory across workspaces.

2. **Submodule State Drift** -- Git submodules point to outdated commits; workers operate on stale code; local commits lost on update.
   - **Avoid:** Track branches not commits, automation scripts for submodule sync, verify submodule state before any work.

3. **Trust Boundary Leakage** -- Agent at Trust Level 3 in Project A retains trust when switching to Project B where they should be Level 0.
   - **Avoid:** Per-workspace trust ledgers, trust level 0 for any agent in new workspace, re-verify trust at workspace switch.

4. **Cross-Project Dependency Cycles** -- Project A depends on B, B depends on A; workers deadlock or changes cascade infinitely.
   - **Avoid:** Dependency graph validation at planning time, acyclic architecture enforcement, versioned interfaces at boundaries.

5. **Priority Starvation** -- High-priority Project A consumes all capacity; lower-priority projects never progress.
   - **Avoid:** Per-project minimum quotas, aging priority, starvation alarms (no activity > N days).

**Pitfall confidence:** HIGH (verified against 2025-2026 production failures and academic research)

## Implications for Roadmap

Based on research, suggested 5-phase structure:

### Phase 1: Foundation (Workspace Registry & Isolation)
**Rationale:** Isolation must be enforced before any multi-workspace execution; registry required for all subsequent phases.
**Delivers:** Workspace registry schema, bootstrap script, health check, per-workspace trust ledgers.
**Addresses Features:** Workspace registration, per-project trust isolation.
**Avoids Pitfalls:** Context contamination (#1), trust boundary leakage (#4), submodule state drift (#2).
**Estimated scope:** Small -- registry schema, 2-3 scripts, trust ledger refactor.

### Phase 2: Local Dispatch (Single-Machine Multi-Workspace)
**Rationale:** Enables end-to-end testing before adding network complexity; depends on Phase 1 registry.
**Delivers:** Dispatch with `--workspace` flag, workspace path resolution, local execution (cd && execute.sh).
**Addresses Features:** Project-scoped dispatch, cross-project priority setting.
**Implements:** Cross-Workspace Dispatch component (Mode 1).
**Avoids Pitfalls:** Cross-project cycles (#3) via dependency validation.
**Estimated scope:** Medium -- extend dispatch.sh, orchestrator skill modifications.

### Phase 3: Status Aggregation (Portfolio Visibility)
**Rationale:** CEO needs visibility before scaling dispatch; can parallel with Phase 2.
**Delivers:** `--portfolio` mode for aggregate.sh, portfolio dashboard view, aggregated briefing with project sections.
**Addresses Features:** Cross-project aggregation, unified inbox, aggregated briefing, project health summary.
**Avoids Pitfalls:** Status staleness (#6) via freshness metadata.
**Estimated scope:** Medium -- extend aggregate.sh, briefing template changes.

### Phase 4: Trust Inheritance & Approval Gates
**Rationale:** Required before autonomous multi-workspace operation; depends on Phase 2.
**Delivers:** Workspace constraint derivation, cross-workspace approval gate, audit logging.
**Implements:** Trust Inheritance component.
**Avoids Pitfalls:** Trust boundary leakage (#4), resource contention (#7).
**Estimated scope:** Small-Medium -- extend hooks.sh, approval workflow.

### Phase 5: Remote Dispatch & Antigravity Integration
**Rationale:** Production readiness; depends on Phases 1-4 working locally.
**Delivers:** Repository dispatch workflow template, async completion detection, Antigravity Inbox integration.
**Implements:** Cross-Workspace Dispatch (Mode 2), Antigravity integration layer.
**Addresses Features:** Template propagation (partial), cross-workspace search (via Antigravity).
**Avoids Pitfalls:** Observability fragmentation (#10) via correlation IDs.
**Estimated scope:** Medium -- GitHub workflow template, Antigravity skill adaptation.

### Phase Ordering Rationale

- **Isolation first:** Pitfalls #1, #2, #4 are CRITICAL and occur in all subsequent phases. Build isolation foundation before any cross-workspace execution.
- **Local before remote:** Validate patterns on single machine before adding network latency and GitHub Actions complexity.
- **Visibility early:** Status aggregation (Phase 3) can parallel with dispatch (Phase 2) since they're independent components.
- **Trust gates before autonomy:** Phase 4 ensures cross-workspace operations are properly approved before Phase 5 enables remote autonomous dispatch.
- **Antigravity last:** Integration layer validates after core functionality works without it; Antigravity is enhancement, not dependency.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** Per-workspace trust ledger migration -- needs design review for backward compatibility with v1.0 format.
- **Phase 5:** Antigravity Inbox integration -- specific API/skill format undocumented, requires exploratory testing.

Phases with standard patterns (can skip `/gsd:research-phase`):
- **Phase 2:** Local dispatch is straightforward cd && execute pattern, well-documented.
- **Phase 3:** Status aggregation via gh CLI is established pattern from v1.0.
- **Phase 4:** Trust inheritance mirrors existing sub-agent scoping, documented in 06-CONTEXT.md.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Context7 + official Google/Claude docs + community verification |
| Features | MEDIUM-HIGH | Synthesized from portfolio management patterns, validated against v1.0 extension model |
| Architecture | MEDIUM-HIGH | Based on existing v1.0 patterns extended to multi-workspace; some decisions need validation |
| Pitfalls | HIGH | Verified against 2025-2026 production failures, academic research, multi-tenant security literature |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Antigravity execution policy mapping:** Concept verified, exact configuration syntax needs testing. Handle during Phase 5 planning.
- **Windows symlink behavior:** Symlinks for skills portability may fail on Windows; fallback to copy documented. Validate in Phase 1.
- **Submodule branch tracking:** Best practice documented but not yet implemented in v1.0. Add automation scripts in Phase 1.
- **Cross-workspace correlation IDs:** Pattern clear but implementation format not specified. Define during Phase 5 planning.
- **Portfolio aggregation frequency:** On-demand vs cached vs scheduled not decided. Defer decision to Phase 3 planning based on CEO workflow.

## Open Questions Requiring Resolution

1. **Workspace registration format:** YAML config (recommended) vs filesystem presence detection? Impacts bootstrap script complexity.
2. **Aggregation freshness thresholds:** How stale is too stale for CEO decisions? Need to define acceptable latency.
3. **Trust demotion scope:** If agent fails critically in Project A, should trust demote globally or just in A? Security vs usability tradeoff.
4. **Cross-project priority model:** Numerical rank vs categorical (P0/P1/P2)? Affects fairness algorithm complexity.
5. **Agent Manager integration depth:** Is Antigravity the primary interface (replacing current dashboard) or supplementary? Affects Phase 5 scope.

## Sources

### Primary (HIGH confidence)
- [Google Developers Blog: Build with Antigravity](https://developers.googleblog.com/build-with-google-antigravity-our-new-agentic-development-platform/)
- [Gemini CLI Documentation](https://geminicli.com/docs/cli/commands/)
- [Claude Code Docs: Skills](https://code.claude.com/docs/en/skills)
- [GitHub Events: repository_dispatch](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows)
- [Git Submodules Official](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Azure AI Agent Design Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)

### Secondary (MEDIUM confidence)
- [Claude Code Multi-directory Support](https://claudelog.com/faqs/--add-dir/)
- [Antigravity Skills Integration](https://medium.com/@joe.njenga/google-antigravity-can-now-use-your-claude-code-skills-i-just-tested-new-agent-skills-7c5d33ca8c86)
- [Multi-Tenant AI Leakage](https://layerxsecurity.com/generative-ai/multi-tenant-ai-leakage/)
- [Portfolio Management Best Practices](https://www.smartsheet.com/content/project-portfolio-dashboards)
- [Multi-Project Resource Scheduling](https://www.epicflow.com/blog/managing-resources-in-a-multi-project-environment-common-challenges-and-ways-to-prevent-them/)

### Tertiary (needs validation)
- Antigravity execution policy syntax -- needs hands-on testing
- Windows Git Bash path handling with Antigravity -- claimed cross-platform, edge cases unclear

---
*Research completed: 2026-01-29*
*Ready for roadmap: yes*

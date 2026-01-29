# Feature Landscape: Multi-Workspace Orchestration

**Domain:** Multi-repository AI agent orchestration for development agency
**Researched:** 2026-01-29
**Confidence:** MEDIUM (WebSearch verified with multiple sources, builds on existing v1.0 milestone)

## Context

This research extends the existing single-project Manifest Automations system to multi-workspace orchestration. The v1.0 milestone already provides:
- Complete CEO -> Orchestrator -> Worker -> GitHub -> Inbox loop
- Trust guardrails with audit chain
- Sub-agent parallelization
- Daily briefing generation
- Label-based state machine for workers

The focus here is specifically on features needed when managing 2-3+ repositories through Anti-Gravity Agent Manager.

---

## Table Stakes

Features users expect for multi-project management. Missing = system feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Cross-project status aggregation** | CEO needs single view across all managed repos | Medium | Existing dashboard aggregates single project; must extend to combine data from multiple `.worker/` directories. Pattern: Portfolio rollups that combine metrics from multiple projects into executive-level summaries. |
| **Unified inbox across projects** | Notifications from all projects in one stream | Medium | Current inbox is project-local. Multi-workspace needs aggregation with project tagging. See [Universal Inbox](https://www.universal-inbox.com/) pattern - "single source of truth for all notifications." |
| **Project context switching** | CEO must be able to focus on specific project when needed | Low | Natural language routing: "Show me Project X status" drills into single project. Current `/dashboard` becomes multi-project; add project filter. |
| **Cross-project priority setting** | CEO sets relative priorities across projects | Medium | Resources (agents, attention) are shared. Must allocate across competing priorities. [RICE framework](https://www.smartsheet.com/content/resource-allocation-multi-project) for quantitative prioritization. |
| **Project-scoped work dispatch** | "Create feature X in Project Y" routes correctly | Low | Extend existing orchestrator to include project routing in dispatch. Natural language parsing already exists; add project entity recognition. |
| **Aggregated daily briefing** | One briefing covering all projects, not N briefings | Medium | Current `generate-briefing.sh` reads single `.worker/`. Must iterate across registered workspaces. Collapsible sections per project. |
| **Project health summary** | Quick glance at which projects need attention | Low | Traffic light indicators (green/yellow/red) per project based on blockers, trust, velocity. Pattern: [Portfolio dashboards with color-coded status](https://www.mastt.com/blogs/project-portfolio-dashboard-best-practices). |
| **Workspace registration** | CEO must register which repos to manage | Low | Configuration file listing managed workspaces. Pattern: Mani CLI uses YAML manifest for multi-repo definitions. |

---

## Differentiators

Features that distinguish this from manual switching between projects.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Cross-project dependency awareness** | Detect when work in Repo A depends on changes in Repo B | High | Pattern: GitHub sub-issues or cross-repo issue references. Orchestrator tracks `Blocked by org/repo#N` syntax. Prevents starting work that's blocked by another project. |
| **Shared context propagation** | When CEO makes decision in one project, related projects get context | Medium | Example: "We're using TypeScript across all projects" applies to all. Shared DECISIONS.md or CEO-DIRECTIVES.md propagated to all workspaces. |
| **Resource-aware dispatch** | Don't over-allocate agents across projects | Medium | Track running agents per project. Avoid CEO getting 10 approval requests simultaneously. Pattern: [Workload balance in multi-project settings](https://www.epicflow.com/blog/how-to-manage-competing-priorities-5-effective-strategies-and-5-tips-to-prevent-them/) - 41% of employees report stress from poor workload management. |
| **Portfolio-level velocity** | "How fast is the agency overall?" metrics | Medium | Aggregate velocity across projects. Show which projects are accelerating/decelerating. Temporal compression metrics: "Agency completed 47 hours of work in 3.2 hours." |
| **Cross-workspace search** | "Which project has that auth implementation?" | Medium | Search across all registered workspaces. Pattern: [Multi-repository indexing](https://www.augmentcode.com/tools/ai-coding-assistants-for-large-codebases-a-complete-guide) - "Full codebase indexing is essential." |
| **Template propagation** | Changes to skills/agents cascade to all projects | High | Agent definitions, GSD skills, worktree scripts shared across projects. Single source of truth for agency tooling. |
| **Per-project trust isolation** | Trust scores stay project-local | Low | Agent misbehavior in Project A doesn't affect trust in Project B. Prevents cross-contamination of trust. |
| **Smart routing based on project state** | Route work to project with capacity | Medium | If Project A has 3 blocked agents and Project B is idle, suggest dispatching to B. Pattern: [Cross-functional resource allocation](https://www.linkedin.com/advice/0/how-do-you-prioritize-allocate-resources-across). |
| **Project grouping / portfolios** | Group projects (e.g., "client work" vs "internal tools") | Low | Hierarchical aggregation: Portfolio -> Projects -> Phases. Filter briefing/dashboard by portfolio. |
| **Workspace health trends** | "Project X velocity declining over 3 days" | Medium | Store historical metrics per workspace. Surface anomalies in briefing. Pattern: [Aggregate project-level issues into portfolio-wide threats](https://www.itonics-innovation.com/blog/project-portfolio-dashboard). |

---

## Anti-Features

Features to explicitly NOT build for multi-workspace. Common mistakes.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Centralized workspace state** | Creates single point of failure, sync nightmares | Keep state local to each workspace (`.worker/`). Aggregate on-demand, don't replicate. Each project remains self-contained and can operate independently. |
| **Cross-project agent sharing** | Agents accumulate project-specific context that doesn't transfer | Keep agents project-scoped. An agent working on Project A has Project A context. Dispatch fresh agents to other projects. |
| **Global trust scores** | Different projects have different risk profiles | Trust stays project-local. Agent may be Level 3 in safe internal project, Level 1 in client-facing project. Project-specific trust thresholds. |
| **Synchronized briefing times** | Different projects may have different stakeholders, timezones | Per-project briefing schedules. Aggregated CEO briefing is optional overlay, not replacement for project briefings. |
| **Single unified worktree** | Mixing project codebases creates confusion, dependency hell | Each project has its own worktree management. Cross-project work uses separate worktrees per project. Pattern: [mu-repo](https://fabioz.github.io/mu-repo/) keeps repos independent. |
| **Cross-project approval bundling** | "Approve all pending" is dangerous | Each approval is project-scoped with project context. Never bundle approvals across projects. Different projects have different risk profiles. |
| **Proprietary project registry** | Another state to manage and sync | Use filesystem presence (registered = has `.worker/` directory) or simple config file. No database for project registration. |
| **Complex permission hierarchies** | N projects x M agents x P permission types = explosion | Keep permissions simple: CEO has all access, agents have project-scoped access. No cross-project permission grants. |
| **Real-time cross-project sync** | Expensive, fragile, rarely needed | On-demand aggregation is sufficient. CEO refreshes dashboard when needed. Projects don't need to know about each other in real-time. |
| **Automatic cross-project coordination** | Subtle cross-project dependencies are complex to detect correctly | Surface potential dependencies to CEO; don't auto-coordinate. CEO decides if dependency is real. |

---

## CEO Workflow

How CEO interacts with multi-workspace system.

### Daily Flow

```
1. CEO opens Mission Control
   -> Sees aggregated dashboard across all projects
   -> Projects sorted by "needs attention" (blockers, approvals, anomalies)

2. CEO reviews daily briefing
   -> Single briefing with collapsible project sections
   -> Blockers from all projects in priority order
   -> Overall agency velocity and health

3. CEO dispatches work
   -> "Add dark mode to Dashboard project"
   -> System routes to correct workspace
   -> Shows decomposition, awaits approval

4. CEO handles approvals
   -> Unified approval queue with project context
   -> Each approval shows which project it's from
   -> Approve/deny with project-specific implications

5. CEO monitors progress
   -> "How's the API project doing?"
   -> Drills into single project view
   -> Returns to portfolio view when done
```

### Key Commands

| Command | Behavior | Notes |
|---------|----------|-------|
| `/dashboard` | Portfolio view across all projects | Default aggregated; can filter by project |
| `/dashboard [project]` | Single project view | Same as v1.0 dashboard |
| `/briefing` | Aggregated briefing | Collapsible sections per project |
| `/status [project]` | Project-specific status | Shorthand for filtered dashboard |
| `/dispatch [intent]` | Auto-routes to correct project | Or explicit: "in [project]..." |
| `/projects` | List registered workspaces | With health indicators |
| `/focus [project]` | Context lock to one project | All commands scoped until `/focus all` |

### Dashboard Layout

```
+-----------------------------------------------------------+
|  PORTFOLIO DASHBOARD                        Refresh [R]    |
+-----------------------------------------------------------+
|  PROJECTS        | OVERALL HEALTH        | TODAY           |
|  [!!] Dashboard  | Blockers: 2           | Dispatched: 7   |
|  [OK] API        | Agents: 4 running     | Completed: 5    |
|  [--] Internal   | Velocity: 4.2 min/avg | Failed: 0       |
+-----------------------------------------------------------+
|  NEEDS ATTENTION (across all projects)                     |
|  [Dashboard] worker-1 awaiting approval (PR #42)           |
|  [API] trust warning: 55 points (threshold: 60)            |
+-----------------------------------------------------------+
|  RECENT COMPLETIONS                                        |
|  [Dashboard] Feature: Dark mode (32 min)                   |
|  [API] Fix: Auth timeout (12 min)                          |
+-----------------------------------------------------------+
```

---

## Feature Dependencies

```
Workspace Registration -> Project Discovery -> Cross-Project Aggregation
                                            -> Per-Project Filtering

Unified Inbox -> Project Tagging -> Priority Sorting
             -> Aggregated Briefing -> Collapsible Sections

Cross-Project Dispatch -> Project Routing -> Existing Orchestrator
                       -> Dependency Detection -> CEO Approval

Portfolio Dashboard -> Health Indicators -> Attention Sorting
                    -> Drill-Down -> Single Project View
```

---

## MVP Recommendation

### Phase 1: Multi-Project Visibility (Must Have)

1. **Workspace registration** - Config file listing managed repos
2. **Cross-project aggregation** - Dashboard reads from multiple `.worker/` dirs
3. **Unified inbox** - Messages tagged by project, single stream
4. **Aggregated briefing** - One briefing, collapsible per-project sections
5. **Project filtering** - `/dashboard [project]` for single-project view

### Phase 2: Multi-Project Dispatch

6. **Project-scoped dispatch** - Route intents to correct project
7. **Cross-project priority** - CEO sets relative priorities
8. **Resource-aware dispatch** - Track agent allocation per project
9. **Cross-project dependency awareness** - Detect `Blocked by org/repo#N`

### Phase 3: Portfolio Intelligence (Differentiators)

10. **Portfolio velocity metrics** - Agency-wide temporal compression
11. **Workspace health trends** - Historical metrics, anomaly detection
12. **Shared context propagation** - CEO decisions cascade to all projects
13. **Cross-workspace search** - Find implementations across repos

### Defer to Post-MVP

- **Template propagation** - Complex sync, validate manual pattern first
- **Project grouping** - Nice-to-have, 2-3 projects don't need grouping
- **Smart routing based on project state** - Complex heuristics, defer
- **Real-time sync** - Expensive, on-demand is sufficient

---

## Complexity vs Value Matrix

| Quadrant | Features |
|----------|----------|
| **High Value, Low Complexity** (Do First) | Workspace registration, Project filtering, Project-scoped dispatch, Per-project trust isolation |
| **High Value, Medium Complexity** (Do Next) | Cross-project aggregation, Unified inbox, Aggregated briefing, Cross-project priority setting |
| **Medium Value, Medium Complexity** (Phase 3) | Portfolio velocity, Workspace health trends, Shared context propagation, Cross-workspace search |
| **Low Value, High Complexity** (Avoid) | Template propagation, Real-time sync, Automatic cross-project coordination |

---

## Implementation Notes

### What Changes From v1.0

| Component | v1.0 Behavior | Multi-Workspace Behavior |
|-----------|---------------|--------------------------|
| Dashboard | Single `.worker/` | Iterates registered workspaces |
| Briefing | Single project | Aggregated with project sections |
| Inbox | Project-local | Aggregated with project tags |
| Dispatch | Implicit project | Explicit or inferred project routing |
| Trust | Global | Per-project (already isolated) |
| Approvals | Project-local | Aggregated queue with project context |

### Key Design Decisions Needed

1. **Workspace registration format** - YAML config vs filesystem presence?
2. **Aggregation frequency** - On-demand vs cached vs real-time?
3. **Project identification** - By directory name vs explicit ID?
4. **Cross-project priority model** - Numerical rank vs categorical?
5. **Briefing ordering** - By priority vs alphabetical vs health status?

### Success Criteria for Real Multi-Repo Workday

- [ ] CEO sees unified dashboard across 2-3 repos
- [ ] Daily briefing covers all projects in one view
- [ ] Work dispatches to correct project via natural language
- [ ] Approvals show project context, handled in unified queue
- [ ] CEO can drill into single project when needed
- [ ] No project knowledge leaks into unrelated projects
- [ ] System works when one project has issues (isolation)

---

## Sources

### Portfolio Management
- [ITONICS: Living Project Portfolio Dashboard](https://www.itonics-innovation.com/blog/project-portfolio-dashboard)
- [Smartsheet: Project Portfolio Dashboards](https://www.smartsheet.com/content/project-portfolio-dashboards)
- [Mastt: Project Portfolio Dashboard Best Practices](https://www.mastt.com/blogs/project-portfolio-dashboard-best-practices)

### Multi-Repository Tools
- [GitKraken: Multi-Repo Management Hurdles](https://www.gitkraken.com/blog/multi-repo-management-hurdles-and-solutions)
- [Mani CLI: Multi-Repository Tool](https://dev.to/alajmo/mani-a-cli-tool-to-manage-multiple-repositories-1eg)
- [mu-repo: Multiple Git Repositories](https://fabioz.github.io/mu-repo/)
- [Moderne CLI: Multi-Repo Developer Experience](https://www.moderne.ai/blog/moderne-cli-multi-repo-developer-experience-automated-code-refactoring)

### Unified Inbox
- [Universal Inbox](https://www.universal-inbox.com/) - "Single source of truth for all notifications"
- [Notico: Unified Inbox for Focus](https://www.notificationcompany.com/post/tackling-notification-overload-a-unified-inbox-for-focus-and-productivity)
- [TeamPlatform: Notification Aggregation](https://www.teamplatform.com/notification-aggregation)

### Cross-Project Priority
- [BirdView: Resource Allocation Across Projects](https://birdviewpsa.com/resource-management-guide/faq/how-allocate-resources-across-multiple-projects/)
- [Saviom: Resource Planning Multiple Projects](https://www.saviom.com/blog/resource-planning-across-multiple-projects/)
- [Epicflow: Managing Competing Priorities](https://www.epicflow.com/blog/how-to-manage-competing-priorities-5-effective-strategies-and-5-tips-to-prevent-them/)
- [Smartsheet: Multi-Project Resource Allocation](https://www.smartsheet.com/content/resource-allocation-multi-project)

### AI Orchestration Patterns
- [Microsoft: AI Agent Design Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)
- [OpenAI: Orchestrating Multiple Agents](https://openai.github.io/openai-agents-python/multi_agent/)
- [IBM: AI Agent Orchestration](https://www.ibm.com/think/topics/ai-agent-orchestration)
- [Google Cloud: Agentic AI Design Patterns](https://docs.cloud.google.com/architecture/choose-design-pattern-agentic-ai-system)

### Multi-Project Context
- [Augment Code: AI Assistants for Large Codebases](https://www.augmentcode.com/tools/ai-coding-assistants-for-large-codebases-a-complete-guide)
- [Anthropic: Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Nx Blog: Practical Guide Effective AI](https://nx.dev/blog/practical-guide-effective-ai-coding)

### Monorepo vs Multi-Repo
- [Thoughtworks: Monorepo vs Multirepo](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/monorepo-vs-multirepo)
- [Kinsta: Monorepo vs Multi-Repo](https://kinsta.com/blog/monorepo-vs-multi-repo/)
- [GitKraken: Monorepo vs Multi-Repo Collaboration](https://www.gitkraken.com/blog/monorepo-vs-multi-repo-collaboration)

---

**Confidence Notes:**
- **HIGH confidence:** Table stakes features - verified across multiple portfolio management sources
- **MEDIUM confidence:** Differentiators - synthesized from multi-repo tooling patterns applied to AI orchestration
- **LOW confidence:** None flagged - all recommendations based on existing v1.0 patterns extended to multi-workspace

---

*Research completed: 2026-01-29*
*Extends existing v1.0 milestone research*

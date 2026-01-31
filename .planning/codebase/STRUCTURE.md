# Codebase Structure

**Analysis Date:** 2026-01-31

## Directory Layout

```
Manifest Automations/
├── .claude/                      # Agency-wide Claude configuration
│   ├── agents/                   # Agent manifest declarations
│   ├── commands/                 # CLI-style command definitions
│   │   ├── research/             # Research domain commands
│   │   └── worker/               # Worker execution commands
│   ├── skills/                   # Reusable workflow implementations
│   │   ├── ceo-dashboard/        # Executive visibility skill
│   │   └── worker/               # Issue execution orchestration
│   └── settings.json             # Trust and permission configuration
├── .planning/                    # Agency-level planning and tracking
│   ├── phases/                   # Milestone phase planning (phases 01-12)
│   │   ├── 01-foundation/        # Core infrastructure (git, worktrees, schemas)
│   │   ├── 02-github-coordination/ # GitHub integration and issue coordination
│   │   ├── 03-worker-foundation/ # Worker lock and state management
│   │   ├── ...
│   │   └── 12-anti-gravity/      # Integration with Agent Manager
│   ├── milestones/               # v1.0 and v1.1 milestone tracking
│   ├── codebase/                 # Codebase analysis documents (maps, concerns)
│   ├── config.json               # Planning configuration (mode, depth, workflow)
│   └── active-projects.md        # Registry of managed workspaces
├── .worker/                      # Runtime execution state and audit
│   ├── agents/                   # Active agent registries per workspace
│   ├── approvals/                # Approval workflow state
│   │   ├── pending/              # Awaiting human decision
│   │   └── approved/             # Executed approvals
│   ├── audit/                    # Execution history and state transitions
│   ├── briefings/                # Generated briefings and dashboard data
│   ├── cache/                    # Performance caches (5-min TTL)
│   ├── inbox/                    # CEO inbox messages and notifications
│   ├── violations/               # Trust violations and incident tracking
│   ├── config.json               # Worker configuration (timeouts, thresholds)
│   └── lock/                     # Exclusive access locks for issue execution
├── .gemini/                      # Multi-model orchestration (Google Gemini config)
├── .cache/                       # GitHub API response cache (for rate limiting)
├── scripts/                      # Executable automation scripts
│   ├── worker/                   # Issue execution and worktree lifecycle
│   │   ├── execute.sh            # Main issue execution orchestrator
│   │   ├── spawn-subagent.sh     # Spawn parallel subagent workers (Phase 6)
│   │   ├── aggregate-wave.sh     # Aggregate wave results (Phase 6)
│   │   └── lib/                  # Shared libraries (logger, lock, parser, audit)
│   ├── dispatch/                 # Workspace dispatch and routing
│   │   ├── dispatch-to-workspace.sh # Route work to specific workspace
│   │   ├── fuzzy-match.sh        # Workspace name resolution (Levenshtein)
│   │   ├── trust-validation.sh   # Pre-execution trust ceiling validation
│   │   └── approval-gate.sh      # Approval workflow execution
│   ├── ceo/                      # CEO interface and dashboard rendering
│   │   ├── dashboard.sh          # Render real-time executive dashboard
│   │   ├── briefing.sh           # Generate briefing documents
│   │   └── portfolio/            # Multi-workspace portfolio status
│   ├── orchestrator/             # Phase planning and orchestration
│   ├── github/                   # GitHub API interactions
│   ├── workspace/                # Workspace discovery and management
│   ├── tests/                    # Test suite and validation
│   ├── worktree-*.sh             # Git worktree lifecycle management
│   └── README.md                 # Scripts documentation
├── projects/                     # Managed workspaces (git submodules)
│   ├── test-project/             # Example project workspace
│   ├── high-trust-workspace/     # High-trust workspace example
│   └── unhealthy-test/           # Test fixture for health validation
├── templates/                    # Bootstrap templates for new entities
│   ├── new-project/              # Project workspace template
│   ├── agent-manifest/           # Agent manifest template
│   ├── workspace/                # Workspace init template
│   ├── github/                   # GitHub issue/PR body templates
│   └── orchestrator/             # Orchestrator planning templates
├── schemas/                      # Validation schemas
│   └── agent-manifest.schema.json # YAML schema for agent definitions
├── prompts/                      # Generated prompt library (completed/)
├── docs/                         # Documentation and guides
│   └── GUARDRAILS.md             # Trust system and guardrails documentation
├── CLAUDE.md                     # Agency-level conventions and trust model
└── README.md                     # Project overview and getting started
```

## Directory Purposes

**`.claude/`:**
- Purpose: Configuration and behavior definitions for AI agent orchestration
- Contains: Agent manifests (YAML), command definitions (Markdown), skill implementations (SKILL.md + .sh), settings
- Key files: `settings.json` (trust/permissions), agents YAML files, skills with lib/ subdirectories
- Pattern: Each skill has a SKILL.md frontmatter + implementation script + optional lib/ for helpers

**`.planning/`:**
- Purpose: Agency-level planning, tracking, and codebase analysis
- Contains: Phase planning docs (RESEARCH → PLAN → SUMMARY per phase), milestone roadmaps, trust ledger, active projects registry
- Key files: `config.json`, `active-projects.md`, `phases/*/` subdirectories, `codebase/` analysis docs
- Pattern: Phases numbered 01-12 with subdirectories; each phase has multiple plans (01-01-PLAN.md, 01-02-PLAN.md, etc.)

**`.worker/`:**
- Purpose: Runtime state and execution tracking across all issue processing
- Contains: Approval records, audit chains, execution logs, agent registries, caches, violations, briefings
- Key files: `config.json`, `audit/chain.json`, `approvals/` workflow state, `lock/` exclusive access markers
- Pattern: Each execution creates records in audit/, locks, and approval flows

**`scripts/`:**
- Purpose: Executable automation organized by functional domain
- Contains: Worker execution, dispatch routing, CEO dashboard, worktree management, GitHub integration
- Key files: `worker/execute.sh` (main entry), `dispatch/dispatch-to-workspace.sh`, `ceo/dashboard.sh`
- Pattern: Each major domain (worker, dispatch, ceo) has its own directory; shared code in lib/ subdirectories

**`projects/`:**
- Purpose: Managed workspaces as git submodules with isolated trust and planning context
- Contains: Project directories as submodules; each contains `.planning/`, `.claude/`, source code, tests
- Key files: Each project has CLAUDE.md, README.md, trust-ledger.md
- Pattern: Workspace discovery via `.gitmodules`; inherits parent trust but has own ceiling

**`templates/`:**
- Purpose: Reusable bootstrap templates for common entities
- Contains: Project scaffolds, agent manifest examples, workspace initialization, GitHub workflows
- Key files: `new-project/` with standard structure, `workspace/` with trust-ledger template
- Usage: Copy and customize for new projects, workspaces, or agent definitions

**`schemas/`:**
- Purpose: JSON Schema definitions for validation
- Contains: Agent manifest schema for YAML validation
- Key files: `agent-manifest.schema.json` (validates agents/*.yaml files)
- Usage: Referenced in agent YAML files via yaml-language-server directive

## Key File Locations

**Entry Points:**

- `scripts/worker/execute.sh`: Main issue-to-PR execution orchestrator (invoked by GitHub or CLI)
- `.claude/skills/ceo-dashboard/SKILL.md`: CEO dashboard definition (entry to dashboard rendering)
- `scripts/dispatch/dispatch-to-workspace.sh`: Workspace routing entry point (routes work to specific project)
- `.planning/phases/[NN]-*/[NN]-PLAN.md`: Phase planning entry points (human reads to understand phase)

**Configuration:**

- `CLAUDE.md`: Agency conventions, trust model, workflow hierarchy
- `.claude/settings.json`: Trust levels, permissions, workflow configuration
- `.worker/config.json`: Worker timeouts, approval windows, dashboard cache TTL, notification tiers
- `.planning/config.json`: Planning mode, workflow depth, parallelization settings

**Core Logic:**

- `.claude/skills/worker/lib/`: Shared worker libraries (logger.sh, lock.sh, parser.sh, audit.sh, validator.sh)
- `scripts/worker/execute.sh`: Main orchestrator for issue processing state machine
- `scripts/dispatch/dispatch-to-workspace.sh`: Workspace selection and trust validation
- `scripts/ceo/dashboard.sh` + aggregate scripts: Real-time CEO visibility

**Testing:**

- `scripts/tests/`: Test suite including integration tests and validation scripts
- `test-validator.sh`: Root-level test runner

**Audit & State:**

- `.worker/audit/chain.json`: Immutable execution history with timestamps and state transitions
- `.worker/approvals/pending/` and `approved/`: Approval workflow records
- `.worker/lock/issue-*.lock`: Exclusive access markers (prevent concurrent execution)

## Naming Conventions

**Files:**

- **Markdown**: `UPPERCASE.md` for planning docs (BRIEF.md, PLAN.md, SUMMARY.md), lowercase for skills/docs
- **Scripts**: `kebab-case.sh` (execute.sh, spawn-subagent.sh, approve-workflow.sh)
- **Agent manifests**: `kebab-case.yaml` (backend-developer.yaml, code-reviewer.yaml)
- **Lock files**: `issue-[NUMBER].lock` (issue-42.lock)
- **Approval records**: `[TIMESTAMP]-[type].json` (1769671361625815100.json)

**Directories:**

- **Phases**: `NN-kebab-case` (01-foundation, 02-github-coordination, 11-trust-approval-gates)
- **Workspaces**: `kebab-case` under `projects/` (test-project, high-trust-workspace)
- **Skills**: `kebab-case` under `.claude/skills/` (ceo-dashboard, worker)
- **Commands**: `kebab-case` under `.claude/commands/` or domain subdirectories

## Where to Add New Code

**New Feature/Skill:**
- **Skill definition**: `.claude/skills/[skill-name]/SKILL.md` (metadata + documentation)
- **Implementation**: `.claude/skills/[skill-name]/[skill-name].sh` (main script)
- **Shared libs**: `.claude/skills/[skill-name]/lib/` (if used across multiple skills)
- **Templates**: `.claude/skills/[skill-name]/templates/` (for generated output)

**New Phase Planning:**
- **Phase directory**: `.planning/phases/[NN]-phase-name/`
- **Research**: `[NN]-RESEARCH.md` (investigation findings)
- **Plan**: `[NN]-[iteration]-PLAN.md` (execution steps)
- **Summary**: `[NN]-[iteration]-SUMMARY.md` (completion report)

**New Workspace/Project:**
- **Workspace directory**: `projects/[project-name]/` (as git submodule)
- **Project structure**: Copy from `templates/new-project/` or `templates/workspace/`
- **Trust setup**: `projects/[project-name]/trust-ledger.md` (inherits parent ceiling)
- **Registration**: Add entry to `.planning/active-projects.md`

**New Utilities/Helpers:**
- **Shared worker libs**: `scripts/worker/lib/[function-name].sh`
- **Domain-specific scripts**: `scripts/[domain]/[script-name].sh`
- **Global utilities**: `scripts/util/` (if shared across domains)

**New Commands:**
- **Command definition**: `.claude/commands/[domain]/[command-name].md`
- **Command implementation**: Markdown file with frontmatter + description + invocation examples

**New Agent Manifest:**
- **Manifest file**: `.claude/agents/[agent-name].yaml`
- **Template**: Copy from `templates/agent-manifest/base.yaml` and customize
- **Validation**: Must conform to `schemas/agent-manifest.schema.json`

## Special Directories

**`.worker/`:**
- Purpose: Runtime state, never committed to git
- Generated: Yes (created at runtime by worker scripts)
- Committed: No (in .gitignore)
- Lifetime: Persistent across sessions; cleaned by `worktree-cleanup.sh`

**`prompts/completed/`:**
- Purpose: Archive of generated prompts from research commands
- Generated: Yes (by `create-prompt.md` command)
- Committed: Yes (for reference and audit)
- Pattern: One file per research session with timestamp

**`.cache/github/`:**
- Purpose: GitHub API response caching to avoid rate limits
- Generated: Yes (by GitHub integration scripts)
- Committed: No (in .gitignore)
- TTL: Depends on cache type (usually 1 hour)

**`.test-workspace/`:**
- Purpose: Test fixture for validation and integration tests
- Generated: Yes (created by test scripts)
- Committed: No (in .gitignore)
- Cleanup: Deleted between test runs

---

*Structure analysis: 2026-01-31*

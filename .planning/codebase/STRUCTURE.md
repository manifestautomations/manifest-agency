# Codebase Structure

**Analysis Date:** 2026-01-29

## Directory Layout

```
Manifest Automations/
├── .claude/                     # Claude Code configuration
│   ├── commands/
│   │   ├── research/            # Research commands (create-prompt, run-prompt)
│   │   └── worker/              # Worker execution command
│   ├── skills/
│   │   ├── ceo-dashboard/       # Executive dashboard, briefing, approvals
│   │   ├── worker/              # Worker execution skill + lib/
│   │   └── orchestrate/         # (Gemini-only, referenced)
│   ├── agents/                  # Specialized subagent prompts (for future use)
│   └── hooks/                   # Git hooks (if any)
├── .planning/                   # Agency-level planning & analysis
│   ├── codebase/                # Codebase analysis docs (STACK.md, etc.)
│   ├── phases/                  # Per-phase documentation (01-07)
│   ├── milestones/              # Milestone definitions
│   ├── research/                # Research notes
│   ├── active-projects.md       # Project registry
│   ├── trust-ledger.md          # Trust tracking (references only)
│   └── MILESTONES.md            # Release history
├── .worker/                     # Runtime state for worker system
│   ├── agents/                  # Agent constraint configs
│   ├── approvals/               # Trust approval workflow
│   │   ├── pending/             # Awaiting CEO decision
│   │   ├── approved/            # CEO approved
│   │   ├── denied/              # CEO denied
│   │   └── registry.jsonl       # Approval audit log
│   ├── audit/                   # Hash-chained audit trail
│   │   └── chain.json           # Tamper-evident event log
│   ├── briefings/               # Daily briefing history
│   ├── dispatch/                # Orchestrator dispatch state
│   ├── logs/                    # Worker execution logs (JSONL)
│   ├── locks/                   # Per-issue execution locks
│   ├── violations/              # Trust violation tracking
│   └── config.json              # Runtime configuration
├── .gemini/                     # Gemini orchestrator (external, referenced)
│   └── skills/                  # orchestrate.md (not in this repo)
├── .github/                     # GitHub workflows and config
│   └── workflows/               # CI/CD workflows
├── scripts/                     # Executable shell scripts
│   ├── ceo/                     # CEO interface scripts
│   │   └── README.md            # CEO command guide
│   ├── orchestrator/            # Orchestration scripts
│   │   ├── intent.sh            # Intent classification
│   │   ├── decompose.sh         # Task decomposition
│   │   ├── graph.sh             # Dependency graph analysis
│   │   ├── dispatch.sh          # Worker dispatch
│   │   ├── aggregate.sh         # Status aggregation
│   │   └── README.md            # Orchestrator guide
│   ├── worker/                  # Worker execution scripts
│   │   ├── execute.sh           # Main worker entry point (Phase 3+)
│   │   ├── lib/                 # Worker libraries (Phase 6+)
│   │   │   ├── graph-parser.sh  # Execution graph parsing
│   │   │   └── spawn-subagent.sh # Sub-agent spawning
│   │   ├── aggregate-wave.sh    # Wave result aggregation
│   │   └── (legacy scripts)     # Older worktree management
│   ├── github/                  # GitHub API wrapper scripts
│   │   ├── issue-create.sh      # Create issues
│   │   ├── pr-create.sh         # Create PRs
│   │   ├── issue-claim.sh       # Claim issue ownership
│   │   └── (others)             # Status updates, comments
│   └── README.md                # Scripts overview
├── commands/                    # Named command triggers (legacy)
│   ├── research/                # Research command definitions
│   └── (others)                 # Command index
├── projects/                    # Project submodules (git submodules)
│   ├── project-a/               # Each is separate repo
│   └── project-b/               # Checked in as submodule
├── prompts/                     # Generated prompt library
│   ├── completed/               # Archived prompts
│   └── (active prompts)         # Current active prompts
├── templates/                   # Bootstrapping templates
│   ├── new-project/             # Template for new projects
│   │   ├── .planning/           # Planning directory template
│   │   ├── CLAUDE.md            # Project guidelines template
│   │   └── README.md            # Project readme template
│   ├── agent-manifest/          # Agent definition template
│   ├── documentation/           # Doc templates
│   ├── github/                  # GitHub config templates
│   ├── orchestrator/            # Orchestrator skill template
│   └── project-scaffold/        # Full project bootstrap
├── schemas/                     # JSON schemas and data structures
│   └── (schema definitions)     # Schema files for validation
├── docs/                        # General documentation
│   └── (markdown docs)          # Guides and references
├── CLAUDE.md                    # Agency-level conventions & guidelines
└── README.md                    # Project overview
```

## Directory Purposes

**`.claude/`** - Claude Code framework
- CLI commands accessible from Claude Code interface
- Skills define multi-step workflows
- Agents provide specialized personas (future)
- Organized by domain: ceo-dashboard (UI/approvals), worker (execution)

**`.planning/`** - Agency project management
- codebase/: Analysis documents (STACK.md, ARCHITECTURE.md, etc.)
- phases/: Numbered phases 01-07 with RESEARCH/PLAN/SUMMARY structure
- milestones/: Release coordination
- trust-ledger.md: Agent trust score tracking (in parent sessions)

**`.worker/`** - Runtime state system
- agents/: Agent configuration and constraints
- approvals/: Trust approval workflow state (JSON files, JSONL registry)
- audit/: Hash-chained event log for tamper detection
- dispatch/: Current dispatch state (what's running)
- locks/: Per-issue mutex files to prevent concurrent execution
- logs/: JSONL event logs from worker runs
- violations/: Trust violation scores and history
- config.json: Runtime configuration (trust levels, timeouts, notification tiers)

**`.github/`** - GitHub integration
- workflows/: CI/CD pipelines (if any)

**`scripts/`** - Executable automation (NOT npm packages)
- All shell-based, no node_modules
- Organized by domain: ceo/, orchestrator/, worker/, github/
- Each script is independently runnable
- Libraries in subdirectories (worker/lib/, orchestrator helpers)

**`commands/`** - Legacy command triggers
- Pre-dated current `.claude/commands/` structure
- May be deprecated, verify before using

**`projects/`** - Project submodules
- Each project is a separate git repository
- Linked via git submodules for monorepo management
- Follow naming: kebab-case (e.g., `customer-api`, `dashboard-ui`)

**`prompts/`** - Prompt library
- Active prompts for current work
- completed/: Archived prompts from past phases
- Generated during orchestration for traceability

**`templates/`** - Bootstrapping
- new-project/: Template for creating new project repos
- agent-manifest/: Template for agent definitions
- orchestrator/: Skill definition template
- Used by `/setup new-project` command

**`schemas/`** - Data validation
- JSON schemas for issue decomposition, execution graphs, etc.
- Referenced in validation scripts

**`docs/`** - General documentation
- Guides, architectural decisions, troubleshooting

## Key File Locations

**Entry Points:**

- `scripts/orchestrator/intent.sh`: Classify CEO intent (Gemini calls this)
- `scripts/orchestrator/decompose.sh`: Generate task decomposition (Gemini calls this)
- `scripts/orchestrator/dispatch.sh`: Dispatch workers (Gemini calls this)
- `scripts/worker/execute.sh`: Execute single issue (Orchestrator calls this)
- `.claude/skills/ceo-dashboard/SKILL.md`: Dashboard skill (CEO invokes)
- `.claude/skills/ceo-dashboard/briefing.SKILL.md`: Briefing skill (CEO invokes)
- `.claude/skills/ceo-dashboard/approve.SKILL.md`: Approval workflow (CEO invokes)

**Configuration:**

- `CLAUDE.md`: Agency conventions (read by all agents at session start)
- `.worker/config.json`: Runtime configuration (trust levels, timeouts, notification tiers)
- `.planning/active-projects.md`: Project registry

**Core Logic:**

- `scripts/orchestrator/graph.sh`: Dependency DAG analysis (topological sort, cycle detection)
- `scripts/worker/execute.sh`: Worker state machine (planning → awaiting-approval → executing → complete)
- `scripts/worker/lib/graph-parser.sh`: Execution graph parsing (parallel task definition)
- `scripts/worker/spawn-subagent.sh`: Sub-agent wave spawning (parallelization)

**Testing:**

- `test-validator.sh`: Validation test script
- `.worker/test/`: Test data and fixtures

## Naming Conventions

**Files:**

- Shell scripts: `kebab-case.sh` (e.g., `worker-execute.sh`, `create-issue.sh`)
- Markdown docs: `UPPERCASE.md` (ARCHITECTURE.md, CONVENTIONS.md) or `kebab-case.md` (readme.md)
- JSON data: `descriptive-name.json` (config.json, constraints.json, chain.json)
- JSONL logs: `pattern-{TIMESTAMP}.jsonl` (issue-42-2026-01-29T12:34.jsonl)
- Plan files: `issue-{N}-PLAN.md` (issue-42-PLAN.md)

**Directories:**

- Phase directories: `NN-kebab-name/` (01-foundation, 02-github-coordination)
- Worktree paths: `{repo-name}-{branch-name}/` (manifest-automations-issue-42/)
- Sub-agent directories: `.worker/agents/{AGENT_ID}/` (test-agent-123)
- Status icons: `[XX]`, `[..]`, `[??]`, `[OK]`, `[--]` for ASCII rendering

**GitHub Labels:**

- Worker state: `worker:planning`, `worker:awaiting-approval`, `worker:executing`, `worker:complete`
- Errors: `worker:partial`, `worker:failed`
- Task types: Not currently used in code (implementation detail)

## Where to Add New Code

**New Worker Script:**
- Location: `scripts/worker/` or `scripts/worker/lib/` (if library)
- Pattern: Source from `.claude/skills/worker/lib/` for logging, locking, validation
- Example: To add a new sub-agent library, create `scripts/worker/lib/new-feature.sh`

**New Orchestrator Function:**
- Location: `scripts/orchestrator/` (as separate script or function in existing script)
- Pattern: Use `jq` for data processing, GitHub labels for state
- Example: To add new intent type, extend `intent.sh` with new classification

**New CEO Dashboard Component:**
- Location: `.claude/skills/ceo-dashboard/` (new SKILL.md file or template)
- Pattern: Call aggregate-status.sh, render to ASCII, deliver to inbox
- Example: New dashboard widget → new SKILL.md file, new render function

**New Skill or Agent:**
- Location: `.claude/skills/{domain}/` or `.claude/agents/{role}/`
- Pattern: Self-contained markdown file with instructions
- Example: New skill → `skills/new-domain/SKILL.md`

**New Project:**
- Template: Copy `templates/new-project/` to `projects/project-name/`
- Register: Add entry to `.planning/active-projects.md`
- Structure: Each project has its own `.planning/`, `CLAUDE.md`, `README.md`

**Utilities/Helpers:**
- Shared: `scripts/` (domain-specific subdirectories)
- Project-specific: `projects/{name}/scripts/`
- Never: `node_modules/`, external package managers (scripts are bash-only)

## Special Directories

**`.worker/` (Runtime State):**
- Purpose: All worker system state (not code, data only)
- Generated: Yes, created by scripts at runtime
- Committed: .gitkeep files only; actual state files excluded via .gitignore
- Lifecycle: Ephemeral; reset between orchestration runs

**`.planning/codebase/` (Analysis Docs):**
- Purpose: Codebase reference documents (generated by /gsd:map-codebase)
- Generated: Yes, created on demand
- Committed: Yes, should be committed for team visibility
- Contents: STACK.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md

**`projects/` (Submodules):**
- Purpose: Each project is separate git repo linked via submodule
- Generated: No, user-created repositories
- Committed: .gitmodules file tracks submodules
- Structure: Each project follows template from `templates/new-project/`

**`prompts/completed/` (Archive):**
- Purpose: Historical record of prompts used in each phase
- Generated: Yes, manually moved here after phase completion
- Committed: Yes, for audit trail
- Retention: Permanent archive

---

*Structure analysis: 2026-01-29*

<objective>
Establish the foundation for Manifest Automations - an AI agency that orchestrates multiple projects with shared tooling, workflows, and an earned autonomy trust system.

This foundation will serve as the parent structure for all project submodules, enabling simultaneous development across branches and worktrees while progressively building trust from zero to full autonomy.
</objective>

<context>
Working directory: `C:\Users\tyler\Manifest Automations` (this IS the agency root)
Inspiration: taches-cc-resources three-tier hierarchy (commands → skills → agents)
Trust model: Earned autonomy - agents gain trust through successful task completion
Project structure: Flat (agency-root/project-name/)
</context>

<research>
Before implementing, examine the current directory state:
- List existing files and folders to understand what's already present
- Check for any existing .claude/ configuration
- Note any files that should be preserved or integrated
</research>

<requirements>
Create the complete foundation structure for the AI agency:

1. **Directory Structure**
   ```
   Manifest Automations/
   ├── .claude/
   │   ├── commands/           # Lightweight CLI-style prompts
   │   ├── skills/             # Autonomous workflow engines
   │   │   └── expertise/      # Domain knowledge bases
   │   ├── agents/             # Specialized subagent prompts
   │   └── settings.json       # Claude Code configuration
   ├── .planning/              # Agency-level planning artifacts
   │   ├── trust-ledger.md     # Track agent trust scores
   │   └── active-projects.md  # Current project registry
   ├── projects/               # All project submodules live here
   │   └── .gitkeep
   ├── templates/              # Project bootstrapping templates
   │   └── new-project/        # Template for new project init
   ├── prompts/                # Generated prompts (already exists)
   ├── CLAUDE.md               # Agency conventions and guidelines
   └── README.md               # Agency overview
   ```

2. **CLAUDE.md Contents** - Must include:
   - Agency mission and philosophy
   - Trust levels (0-4) with clear criteria for advancement
   - Project conventions (naming, structure, branching)
   - Command/skill/agent naming patterns
   - Worktree workflow guidelines
   - Context handoff protocols

3. **Trust Ledger System** (`.planning/trust-ledger.md`)
   - Trust levels:
     - Level 0: No trust - explicit approval for every action
     - Level 1: Basic trust - can read files, suggest changes
     - Level 2: Limited autonomy - can edit files with verification
     - Level 3: Standard autonomy - can execute plans with checkpoints
     - Level 4: Full autonomy - trusted for complex multi-step operations
   - Metrics tracked: tasks completed, success rate, rollbacks needed
   - Promotion/demotion criteria

4. **Settings Configuration** (`.claude/settings.json`)
   - Default trust level for new sessions
   - Enabled tools and permissions
   - Custom instructions reference

5. **New Project Template** (`templates/new-project/`)
   - Skeleton CLAUDE.md for project-specific conventions
   - Basic .planning/ structure
   - README template
</requirements>

<implementation>
Use these patterns inspired by taches-cc-resources:

- **Composable microcommands**: Small commands invoke larger skills
- **Hierarchical planning**: BRIEF → ROADMAP → Research → PLAN → Execute → SUMMARY
- **Self-healing workflows**: Commands can update based on execution failures
- **Structured data handoffs**: Markdown-based state files for context passing
- **Embedded quality gates**: Auditor agents validate without blocking

For the trust system, implement earned autonomy:
- Start every new context at Level 0
- Track completion metrics in trust-ledger.md
- Require N successful completions at level X before advancing to X+1
- Any rollback or critical failure resets trust by one level
</implementation>

<output>
Create all files with relative paths from the agency root:

- `./CLAUDE.md` - Comprehensive agency guidelines (primary deliverable)
- `./.claude/settings.json` - Initial Claude Code configuration
- `./.planning/trust-ledger.md` - Trust tracking system
- `./.planning/active-projects.md` - Project registry (empty template)
- `./templates/new-project/CLAUDE.md` - Project template
- `./templates/new-project/README.md` - Project readme template
- `./README.md` - Agency overview

Ensure all parent directories are created as needed.
</output>

<verification>
Before declaring complete, verify:

1. All directories exist with proper structure
2. CLAUDE.md contains all required sections (mission, trust levels, conventions)
3. Trust ledger has clear level definitions and metrics
4. Templates are complete and usable
5. Settings.json is valid JSON with sensible defaults
6. Run `tree` or equivalent to display final structure
</verification>

<success_criteria>
- Directory structure matches specification exactly
- CLAUDE.md is comprehensive enough to guide future development
- Trust system is clearly defined with measurable criteria
- Templates are ready for immediate use
- No placeholder content - everything should be production-ready
- Foundation enables the next phase: creating essential commands
</success_criteria>

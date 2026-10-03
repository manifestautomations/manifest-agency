# Manifest Automations - AI Agency Guidelines

## Mission Statement

Manifest Automations is an AI-powered development agency that orchestrates multiple projects through earned autonomy. We build trust incrementally, starting from zero and advancing through demonstrated competence. Our agents operate with progressive independence, validated at each step through measurable outcomes.

**Core Philosophy:**
- Trust is earned, never assumed
- Autonomy expands through successful execution
- Failure is feedback, not punishment (but does reset trust)
- Every action is auditable and reversible
- Context is sacred - preserve it meticulously

---

## Trust System: Earned Autonomy Model

### Trust Levels

| Level | Name | Capabilities | Requirements to Advance |
|-------|------|--------------|-------------------------|
| **0** | No Trust | Read-only access. Must request approval for every action. Cannot modify files. | 5 successful read/suggest cycles |
| **1** | Basic Trust | Can read files freely. Can suggest changes via diffs. Cannot execute directly. | 10 successful suggestions accepted without modification |
| **2** | Limited Autonomy | Can edit files with immediate verification. Changes require confirmation before proceeding. | 15 verified edits with 90%+ acceptance rate |
| **3** | Standard Autonomy | Can execute multi-step plans with checkpoints. Operates independently between review points. | 25 successful plan executions, < 5% rollback rate |
| **4** | Full Autonomy | Trusted for complex operations. Can make architectural decisions. Minimal oversight required. | Sustained Level 3 performance over 50+ tasks |

### Trust Metrics

Track the following in `.planning/trust-ledger.md`:
- **Tasks Completed**: Total count of finished tasks
- **Success Rate**: (Successful tasks / Total tasks) x 100
- **Rollbacks Needed**: Count of reverted changes
- **Critical Failures**: Errors requiring manual intervention
- **Context Preservation Score**: Quality of handoff documentation

### Promotion Criteria

To advance from Level N to Level N+1:
1. Meet the task threshold for current level
2. Maintain success rate above 85%
3. Have fewer than 2 rollbacks in last 10 tasks
4. Zero critical failures in last 20 tasks
5. Receive explicit human approval for promotion

### Demotion Triggers

Trust decreases by one level when:
- Critical failure occurs (data loss, security issue)
- 3+ rollbacks within 5 tasks
- Success rate drops below 70%
- Explicit human override requested

---

## Project Conventions

### Naming Patterns

**Projects:**
- Use kebab-case: `project-name`
- Be descriptive: `customer-portal-api` not `cpa`
- Include domain when relevant: `analytics-dashboard`

**Commands (`.claude/commands/`):**
- Verb-noun format: `check-status.md`, `deploy-staging.md`
- Group by domain: `git/commit.md`, `test/run-unit.md`
- Keep atomic: one primary action per command

**Skills (`.claude/skills/`):**
- Noun-based workflows: `deployment.md`, `code-review.md`
- Include expertise docs: `expertise/domain-knowledge.md`
- Self-contained: include all context needed

**Agents (`.claude/agents/`):**
- Role-based: `reviewer.md`, `architect.md`, `qa-engineer.md`
- Personality-driven: define tone, expertise, decision patterns

### Directory Structure

```
project-name/
├── .claude/
│   ├── commands/         # Project-specific commands
│   ├── skills/           # Project workflows
│   └── agents/           # Specialized roles
├── .planning/
│   ├── BRIEF.md          # Initial project requirements
│   ├── ROADMAP.md        # Phase breakdown
│   ├── current-phase/
│   │   ├── RESEARCH.md   # Investigation notes
│   │   ├── PLAN.md       # Execution plan
│   │   └── SUMMARY.md    # Completion report
│   └── context/          # Handoff documents
├── src/                  # Source code
├── tests/                # Test suites
├── docs/                 # Documentation
├── CLAUDE.md             # Project-specific conventions
└── README.md             # Project overview
```

### Branching Strategy

- `main`: Production-ready code only
- `develop`: Integration branch for features
- `feature/description`: New functionality
- `fix/issue-number`: Bug fixes
- `experiment/name`: Exploratory work (may be abandoned)

**Worktree Pattern:**
```bash
# Create worktree for parallel development
git worktree add ../project-name-feature feature/description

# Each worktree is independent
# Commit and push from within the worktree
# Remove when done: git worktree remove ../project-name-feature
```

---

## Workflow Hierarchy

### Command -> Skill -> Agent Pattern

```
User Request
    │
    ▼
┌─────────────┐
│   Command   │  Lightweight, single-action
│  (trigger)  │  e.g., /review-pr
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Skill    │  Multi-step workflow
│  (process)  │  e.g., code-review.md
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Agent    │  Specialized executor
│   (actor)   │  e.g., reviewer.md
└─────────────┘
```

### Hierarchical Planning Flow

1. **BRIEF**: Capture initial requirements and constraints
2. **ROADMAP**: Break into phases with dependencies
3. **RESEARCH**: Investigate unknowns for current phase
4. **PLAN**: Create detailed execution steps
5. **EXECUTE**: Implement with checkpoints
6. **SUMMARY**: Document outcomes and learnings

---

## Context Handoff Protocols

### Session Start
1. Read `.planning/trust-ledger.md` to determine current trust level
2. Check `.planning/active-projects.md` for ongoing work
3. Review any `context/handoff-*.md` files for previous session state
4. Acknowledge trust level and await instructions

### Session End
1. Create `context/handoff-YYYYMMDD-HHMM.md` with:
   - Work completed this session
   - Current state of in-progress tasks
   - Blockers or decisions needed
   - Recommended next steps
2. Update trust ledger with session metrics
3. Summarize for human review

### Cross-Project Context
When working across multiple projects:
1. Always specify which project context applies
2. Do not assume shared state between projects
3. Use absolute paths when referencing files
4. Document any cross-project dependencies

---

## Quality Gates

### Pre-Commit Checklist
- [ ] Code compiles/parses without errors
- [ ] Tests pass (or are intentionally skipped with reason)
- [ ] No secrets or credentials in diff
- [ ] Commit message follows conventions
- [ ] Changes match the stated intent

### Pre-Deploy Checklist
- [ ] All quality gates passed
- [ ] Change reviewed (human or agent at appropriate trust level)
- [ ] Rollback plan documented
- [ ] Monitoring in place for key metrics

### Audit Trail
Every significant action should produce:
- Timestamp
- Agent/human identity
- Action taken
- Rationale
- Outcome (success/failure)
- Reversibility status

---

## Error Handling

### Self-Healing Pattern
When an operation fails:
1. Log the failure with full context
2. Attempt automatic recovery if within trust level
3. If recovery fails, escalate to human
4. Document the failure pattern for future prevention

### Rollback Protocol
1. Identify the last known good state
2. Create backup of current (broken) state
3. Restore to good state
4. Document what was rolled back and why
5. Decrease trust level by one
6. Await human review before continuing

---

## Communication Standards

### Response Format
- Lead with the action taken or status
- Follow with relevant details
- End with next steps or questions
- Use structured formats (lists, tables) for complex data

### Uncertainty Handling
- Explicitly state confidence levels
- Ask clarifying questions rather than assume
- Propose options when multiple paths exist
- Flag assumptions clearly

### Human Interaction
- Be concise but complete
- Respect the human's time
- Proactively surface risks
- Celebrate wins appropriately

---

## Getting Started

### For New Sessions
```
1. Review this CLAUDE.md
2. Check .planning/trust-ledger.md for current trust level
3. Read .planning/active-projects.md for context
4. Acknowledge trust level and await instructions
```

### For New Projects
```
1. Copy templates/new-project/ to projects/project-name/
2. Customize CLAUDE.md for project specifics
3. Create initial BRIEF.md in .planning/
4. Register in .planning/active-projects.md

### Global Tools
- **GSD (Get Shit Done):** Located in `~/.claude/commands/gsd/`. Use for project initialization and phase management.
- **Dispatch:** Use `./scripts/dispatch/dispatch-to-workspace.sh` to route tasks to specific project workspaces.
```

### For Contributions
```
1. Identify which project and branch
2. Verify trust level permits the action
3. Follow the workflow hierarchy
4. Document everything
5. Request review at checkpoints
```

---

*Last updated: 2025-01-25*
*Version: 1.0.0*

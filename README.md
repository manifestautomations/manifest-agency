# Manifest Automations

An AI-powered development agency that orchestrates multiple projects through earned autonomy.

## Vision

Manifest Automations is a new paradigm for AI-assisted software development. Rather than treating AI as a simple tool, we implement a structured trust system where AI agents earn progressive autonomy through demonstrated competence.

**Core Principles:**
- **Earned Trust**: Every session starts at zero. Trust is built through successful task completion.
- **Progressive Autonomy**: As trust grows, so does independence. From read-only to full autonomy.
- **Auditable Actions**: Every decision is logged, every action is reversible.
- **Context Preservation**: Knowledge flows between sessions through structured handoffs.

## Structure

```
Manifest Automations/
├── .claude/                 # Claude Code configuration
│   ├── commands/            # CLI-style prompt triggers
│   ├── skills/              # Autonomous workflow engines
│   │   └── expertise/       # Domain knowledge bases
│   └── agents/              # Specialized subagent prompts
├── .planning/               # Agency-level planning
│   ├── trust-ledger.md      # Trust score tracking
│   └── active-projects.md   # Project registry
├── projects/                # All project submodules
├── templates/               # Project bootstrapping & Asset Library
│   ├── contracts/           # SOWs and Legal Agreements
│   ├── marketing/           # Case Studies & Positioning
│   ├── outreach/            # Email Sequences
│   ├── reporting/           # Weekly Status Reports
│   ├── team/                # Wins Tracker & Culture
│   ├── website/             # Copy & Landing Pages
│   └── new-project/         # Project Scaffold
├── prompts/                 # Generated prompt library
├── CLAUDE.md                # Agency conventions
└── README.md                # This file
```

## Template Library

We maintain a library of standardized assets to ensure consistency and speed.

### 📜 Contracts & Legal (`templates/contracts/`)
- **Discovery SOW**: `SOW-Discovery.md` (Paid roadmapping)
- **Implementation SOW**: `SOW-Implementation.md` (Build phase)

### 📣 Marketing & Sales (`templates/marketing/` & `templates/outreach/`)
- **Competitor Analysis**: `competitor-analysis.md` (Positioning strategy)
- **Case Study Template**: `case-study-template.md` (Problem/Solution/Result)
- **Email Sequences**: `follow-up-sequences.md` (Sales follow-ups)

### 📊 Operations (`templates/reporting/` & `templates/team/`)
- **Weekly Report**: `weekly-report-template.md` (Status updates)
- **Wins Tracker**: `wins-tracker.md` (Team morale & milestones)

### 🌐 Website (`templates/website/`)
- **Landing Page Copy**: `landing-page-copy.md` (Main site content)

## Trust System

The agency operates on a 5-level trust model:

| Level | Name | Description |
|-------|------|-------------|
| 0 | No Trust | Read-only, explicit approval for all actions |
| 1 | Basic Trust | Can suggest changes, no direct modification |
| 2 | Limited Autonomy | Can edit with verification |
| 3 | Standard Autonomy | Execute plans with checkpoints |
| 4 | Full Autonomy | Trusted for complex operations |

See `CLAUDE.md` for detailed criteria and advancement rules.

## Getting Started

### For Humans

1. Clone this repository
2. Review `CLAUDE.md` for conventions
3. Check `.planning/active-projects.md` for current work
4. Use `/commands` to trigger workflows

### For AI Agents

1. Read `CLAUDE.md` completely
2. Check current trust level in `.planning/trust-ledger.md`
3. Acknowledge trust level and await instructions
4. Follow the command -> skill -> agent hierarchy

## Creating a New Project

```bash
# Copy the template
cp -r templates/new-project projects/my-project

# Customize the configuration
# Edit projects/my-project/CLAUDE.md
# Edit projects/my-project/README.md

# Register the project
# Add entry to .planning/active-projects.md

# Create initial planning docs
# projects/my-project/.planning/BRIEF.md
```

## Workflow Hierarchy

```
Command (trigger) -> Skill (process) -> Agent (actor)

Example:
/review-pr -> code-review.md -> reviewer.md
```

- **Commands**: Lightweight, single-action triggers
- **Skills**: Multi-step autonomous workflows
- **Agents**: Specialized personas with domain expertise

## Contributing

1. All contributions start at Trust Level 0
2. Follow the workflow hierarchy
3. Document everything in `.planning/`
4. Request review at checkpoints
5. Earn trust through successful completion

## License

Proprietary - Manifest Automations

---

*Building the future of AI-assisted development, one earned trust level at a time.*

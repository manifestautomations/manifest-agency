# {{WORKSPACE_NAME}} - AI Agent Guidelines

## Trust System

This workspace operates under the Manifest Automations earned autonomy model.

**Trust Ledger:** `.planning/trust-ledger.md`

Current trust level and capabilities are defined in the trust ledger. Review before starting any session.

### Quick Reference

| Level | Name | Key Capability |
|-------|------|----------------|
| 0 | No Trust | Read-only, suggest changes |
| 1 | Basic Trust | Read freely, suggest with context |
| 2 | Limited Autonomy | Edit files with verification |
| 3 | Standard Autonomy | Multi-step plans with checkpoints |
| 4 | Full Autonomy | Complex operations, minimal oversight |

## Project Structure

```
{{WORKSPACE_NAME}}/
├── .planning/
│   └── trust-ledger.md    # Trust status and history
├── .claude/
│   ├── commands/          # Project-specific commands
│   └── skills/            # Project workflows
├── src/                   # Source code
├── CLAUDE.md              # This file
└── README.md              # Project overview
```

## Session Protocol

### Starting a Session
1. Read `.planning/trust-ledger.md` for current trust level
2. Review any recent session notes
3. Acknowledge trust level before proceeding

### Ending a Session
1. Document work completed
2. Update trust ledger with session metrics
3. Note any blockers or next steps

## Project-Specific Conventions

*Add project-specific guidelines here as the project evolves.*

---

*Managed workspace under Manifest Automations*

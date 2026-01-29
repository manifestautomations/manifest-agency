---
name: approve
description: Approve or deny a pending high-stakes action request from an agent
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Approval Workflow Skill

Handle pending approval requests from agents for high-stakes actions.

**Manual invocation only** - This skill does not auto-trigger to prevent accidental approvals.

## Execution

Handle approval workflow based on what's provided:

### 1. List pending approvals (if no ID provided)

```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh list
```

Shows all pending approvals with:
- Approval ID
- Type
- Agent
- Time remaining

### 2. Show approval context (if ID provided)

```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh context APPROVAL_ID
```

Displays full details:
- Request type and reason
- Requesting agent
- Impact assessment
- Time until timeout

### 3. Process decision

**For "approve":**
```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh approve APPROVAL_ID "justification"
```

**For "deny":**
```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh deny APPROVAL_ID "reason"
```

Always confirm the action before executing.
Show the result (approved/denied) and any follow-up effects.

## Script Integration

The approval workflow is managed by **approval-workflow.sh** which:

1. Reads pending approvals from `.worker/approvals/pending/`
2. Moves decisions to `.worker/approvals/approved/` or `.worker/approvals/denied/`
3. Logs all transitions to `.worker/approvals/registry.jsonl`

## Approval States

| Directory | Meaning |
|-----------|---------|
| `pending/` | Awaiting CEO decision |
| `approved/` | CEO approved the request |
| `denied/` | CEO denied the request |

## Approval File Format

```json
{
  "approval_id": "approval-1234567890",
  "type": "trust_promotion",
  "agent_id": "worker-1",
  "context": {"current": 2, "target": 3},
  "created_at": "2026-01-29T06:30:00Z",
  "timeout_at": "2026-01-29T07:00:00Z",
  "status": "pending"
}
```

## Audit Trail

All decisions are logged to:
- `.worker/approvals/registry.jsonl` - Append-only audit log
- `.worker/audit/` - Integration with Phase 4 audit infrastructure

## Error Handling

- "Approval not found" - ID may have been processed or expired
- "Cannot auto-deny critical violations" - These require manual decision

## Approval Types

| Type | Description | Auto-deny |
|------|-------------|-----------|
| `trust_promotion` | Agent requesting higher trust level | After 24h |
| `critical_violation` | Agent triggered critical guardrail | Never |
| `scope_access` | Agent requesting expanded file access | After 24h |
| `cross_workspace` | Agent requesting cross-project operation | After 24h |

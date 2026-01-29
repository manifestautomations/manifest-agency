---
name: approve
description: Approve or deny a pending high-stakes action request from an agent. Requires approval ID.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Approval Workflow Skill

Handle pending approval requests from agents for high-stakes actions.

**Manual invocation only** - This skill does not auto-trigger to prevent accidental approvals.

## Execution

### List Pending Approvals (no ID provided)

When invoked without an approval ID, list all pending approvals:

```bash
bash .claude/skills/ceo-dashboard/scripts/list-approvals.sh
```

Or manually read from `.worker/approvals/pending/`:

```
PENDING APPROVALS
-----------------
ID        | Type           | Agent      | Timeout
APR-001   | deploy-prod    | worker-1   | 12 min
APR-002   | delete-branch  | worker-3   | 45 min
APR-003   | modify-schema  | worker-2   | 2 hrs

Use: /approve APR-001 [approve|deny] [reason]
```

### Show Approval Details (ID provided)

When invoked with an approval ID, show full context:

```bash
bash .claude/skills/ceo-dashboard/scripts/show-approval.sh APR-001
```

Display:
- **Request ID**: APR-001
- **Type**: High-stakes action category
- **Requesting Agent**: Agent ID that triggered the request
- **Reason**: Why the action was flagged for approval
- **Context**: What the agent was trying to do
- **Impact**: What happens if approved vs denied
- **Timeout**: Time remaining until auto-deny
- **Created**: When the request was submitted

### Process Decision

Accept one of:
- `approve` - Allow the action to proceed
- `deny` - Block the action

Optional justification for audit trail:
- `/approve APR-001 approve "Verified deployment checklist complete"`
- `/approve APR-001 deny "Not ready - missing tests"`

Execute transition via script:

```bash
bash .claude/skills/ceo-dashboard/scripts/process-approval.sh APR-001 approve "justification"
```

Or manually:
1. Read approval file from `.worker/approvals/pending/APR-001.json`
2. Update with decision, justification, timestamp
3. Move to `.worker/approvals/approved/` or `.worker/approvals/denied/`
4. Signal waiting agent (if any) via lock release or webhook

## Approval Types

| Type | Severity | Default Timeout | Auto-Resolution |
|------|----------|-----------------|-----------------|
| deploy-prod | CRITICAL | 30 min | Deny |
| delete-branch | HIGH | 1 hour | Deny |
| modify-schema | HIGH | 2 hours | Deny |
| external-api | MEDIUM | 4 hours | Deny |
| bulk-update | MEDIUM | 4 hours | Deny |
| new-dependency | LOW | 24 hours | Approve |

## Approval File Format

```json
{
  "id": "APR-001",
  "type": "deploy-prod",
  "agent": "worker-1",
  "reason": "Trust level 2 agent attempting production deployment",
  "context": {
    "task": "Deploy feature X to production",
    "issue": 42,
    "files_affected": ["deploy.sh", "config.prod.json"]
  },
  "created_at": "2026-01-29T06:30:00Z",
  "timeout_at": "2026-01-29T07:00:00Z",
  "auto_resolution": "deny"
}
```

## Decision File Format (after processing)

```json
{
  "id": "APR-001",
  "type": "deploy-prod",
  "agent": "worker-1",
  "decision": "approved",
  "decided_by": "ceo",
  "justification": "Verified deployment checklist complete",
  "decided_at": "2026-01-29T06:45:00Z",
  "original_request": { ... }
}
```

## Audit Trail

All decisions are logged to:
- `.worker/approvals/registry.jsonl` - Append-only audit log
- `.worker/audit/` - Integration with Phase 4 audit infrastructure

Registry entry format:
```json
{"id":"APR-001","type":"deploy-prod","decision":"approved","decided_by":"ceo","decided_at":"2026-01-29T06:45:00Z"}
```

## Error Handling

- **Invalid ID**: "Approval APR-XXX not found in pending queue"
- **Already processed**: "Approval APR-001 was already [approved/denied] at [timestamp]"
- **Timeout expired**: "Approval APR-001 auto-resolved to [deny] due to timeout"
- **Invalid decision**: "Decision must be 'approve' or 'deny'"

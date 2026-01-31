---
name: approve
description: Process CEO approval for pending items (cross-workspace dispatch, trust promotions, critical violations)
---

# Approval Workflow Skill

## Goal

Process CEO approval decisions for items requiring explicit authorization.

## Instructions

1. **Parse approval ID:**
   - From argument: `/approve 1769712022771213800`
   - From conversation: "approve that request"
   - Extract timestamp-based ID

2. **Run approval workflow:**
   ```bash
   .claude/skills/ceo-dashboard/scripts/approval-workflow.sh approve <ID>
   ```

3. **Check exit code:**
   - 0: Approval recorded successfully
   - 1: Approval ID not found or already processed
   - 2: Approval denied or validation failed

4. **Report result:**
   ```
   Approved: Cross-workspace dispatch for high-trust-workspace
   - Request ID: approval-1769712021924961400
   - Worker trust level: 3 (ceiling: 2)
   - Approval recorded: .worker/approvals/registry.jsonl
   - Status: Dispatch unblocked, will proceed
   ```

## Approval Types

**Cross-workspace dispatch:**
- Triggered when dispatching to workspace outside current context
- Validates workspace health before proceeding
- Records workspace in approval registry

**Trust promotions:**
- Worker requesting trust level increase
- Validates promotion eligibility (completed tasks, success rate)
- Updates trust ledger after approval

**Critical violations:**
- Worker exceeded trust ceiling
- Security or safety violation detected
- Requires CEO decision: approve exception or deny

## Workflow After Approval

1. **Record approval:**
   - Appends to `.worker/approvals/registry.jsonl`
   - Includes: timestamp, type, workspace, decision, CEO identity

2. **Unblock pending work:**
   - If cross-workspace: dispatch proceeds
   - If trust promotion: ledger updated, worker notified
   - If violation exception: worker continues with caveat

3. **Audit trail:**
   - Approval logged to `.worker/audit/chain.json`
   - Hash-chained for integrity
   - Linked to original request

## Denial Workflow

To deny instead of approve:

```bash
.claude/skills/ceo-dashboard/scripts/approval-workflow.sh deny <ID>
```

Result:
- Blocks pending dispatch
- Logs denial reason
- Notifies requesting agent

## List Pending Approvals

To see all pending approvals:

```bash
.claude/skills/ceo-dashboard/scripts/approval-workflow.sh list
```

Output:
```
Pending Approvals (2):

1. approval-1769712021924961400
   - Type: cross-workspace
   - Workspace: high-trust-workspace
   - Requested: 2026-01-30T06:51:31Z

2. approval-1769712716813896001
   - Type: trust-promotion
   - Worker: test-agent
   - From: Level 2 → Level 3
   - Requested: 2026-01-30T07:15:45Z
```

## Constraints

- Only CEO can approve (authenticated)
- Approvals are immutable (no undo)
- All approvals audited
- Exit-and-resume pattern (dispatch exits after requesting approval, CEO re-runs after approval)

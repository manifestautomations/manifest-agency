---
status: testing
phase: 11-trust-approval-gates
source: 11-01-SUMMARY.md, 11-02-SUMMARY.md
started: 2026-01-31T12:00:00Z
updated: 2026-01-31T12:00:00Z
---

## Current Test

number: 1
name: Trust ceiling blocks high-trust dispatch
expected: |
  When dispatching to a workspace where child trust level exceeds parent ceiling,
  dispatch is blocked with clear error message showing the ceiling violation.
awaiting: user response

## Tests

### 1. Trust ceiling blocks high-trust dispatch
expected: Dispatching to workspace where child trust > parent ceiling shows error with trust levels and blocks dispatch
result: [pending]

### 2. Improvement analysis on ceiling violation
expected: When trust ceiling is violated, system prints actionable improvement analysis to stderr showing what the child workspace does better
result: [pending]

### 3. Graceful default for missing ledger
expected: Workspace with no trust-ledger.md defaults to trust level 0 (most restrictive) - dispatch proceeds but at minimal trust
result: [pending]

### 4. Approval required for trust level 3+
expected: Dispatching to workspace with trust level 3+ creates approval request, shows instructions, and exits (doesn't proceed without approval)
result: [pending]

### 5. Approval instructions include all options
expected: When approval required, instructions show how to approve, deny, modify, and defer the request
result: [pending]

### 6. Re-run after approval proceeds
expected: After approving a cross-workspace request, re-running the same dispatch command succeeds (finds existing approval)
result: [pending]

### 7. Audit trail captures approval context
expected: Dispatch log entries include child_trust_level, approval_status, and approval_id fields
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0

## Gaps

[none yet]

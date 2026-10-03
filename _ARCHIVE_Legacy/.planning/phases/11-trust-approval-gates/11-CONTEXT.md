# Phase 11: Trust & Approval Gates - Context

**Gathered:** 2026-01-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Cross-workspace operations are properly constrained and approved. Child workspace trust cannot exceed parent ceiling. Each workspace trust ledger operates independently. Cross-workspace operations at trust level 3+ require explicit CEO approval.

</domain>

<decisions>
## Implementation Decisions

### Trust Ceiling Behavior
- When child workspace's earned trust exceeds parent ceiling: block the promotion
- Before blocking, generate analysis of WHY child is outperforming (workflows, skills, agents)
- Analysis includes actionable diffs: specific file/config differences that could improve parent
- Automatically create improvement task for parent workspace (pending acceptance, not auto-assigned)
- Child remains at current trust level until parent promotes

### Approval Trigger Criteria
- Trust-gated approval: only operations at trust level 3+ (Standard Autonomy) require approval
- Lower trust operations (reads, suggestions, single edits) pass through without approval
- Trust level alone determines approval — no special-case operation types
- ALL cross-workspace operations are logged regardless of approval requirement (full audit trail)

### Approval Interaction Flow
- Approval requests are blocking prompts — work pauses until CEO responds
- Prompt includes contextual information: why needed, what will change, risk level
- CEO has four response options: Approve, Modify, Deny, Defer
- Deferred approvals become GitHub issues (fits GitHub as coordination layer pattern)

### Ledger Verification Timing
- Verify trust BEFORE routing (fail fast, no wasted work)
- Ledger considered stale if not refreshed since last cross-workspace dispatch (event-driven)
- Stale ledger requires forced recalculation before proceeding
- If ledger refresh reveals trust level change, re-prompt CEO for approval

### Claude's Discretion
- GitHub issue format for deferred approvals (labels, assignees)
- Exact format of actionable diffs in improvement analysis
- Log format for cross-workspace operation audit trail

</decisions>

<specifics>
## Specific Ideas

- Child-to-parent improvement analysis creates a "best hiring practices" feedback loop within the agency
- GitHub issues for deferrals maintains the pattern of GitHub as the durable coordination layer
- Event-driven staleness (since last dispatch) is more meaningful than time-based staleness

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-trust-approval-gates*
*Context gathered: 2026-01-30*

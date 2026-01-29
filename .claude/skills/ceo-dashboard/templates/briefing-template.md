# Daily Briefing - {{date}}

{{#blockers}}
## Blockers

{{#items}}
- **{{type}}** for `{{agent}}`
  - {{context}}
  - Timeout: {{timeout}} | [Approve](cmd:approve {{id}}) | [Deny](cmd:deny {{id}})
{{/items}}

{{/blockers}}

{{#overnight}}
## Overnight Summary

- Completions: {{completions}}
- Failures: {{failures}}
{{#milestones}}
- Milestone: {{description}}
{{/milestones}}

{{/overnight}}

{{#health}}
## Health Indicators

- Average Trust: Level {{avg_trust}}
{{#warnings}}
- Warning: {{count}} agents approaching demotion
{{/warnings}}
{{#critical}}
- CRITICAL: {{count}} agents require immediate attention
{{/critical}}

{{/health}}

{{#progress}}
## Progress Snapshot

- Project: {{percent}}% complete
- Velocity: {{avg_time}} min/task
- Phase: {{current_phase}}

{{/progress}}

{{#outlook}}
## Today's Outlook

- Queued: {{queued}} items
- Pending: {{pending}} items

{{/outlook}}

---
_Generated: {{timestamp}}_

<!--
BRIEFING TEMPLATE REFERENCE

This template uses mustache-style conditional blocks for section collapsing.
Sections with empty data are not rendered.

SECTION PRIORITY ORDER:
1. Blockers - Pending approvals requiring action (highest priority)
2. Overnight - Activity since last briefing
3. Health - Trust anomalies (only shown if warnings/critical exist)
4. Progress - Project completion snapshot
5. Outlook - Queued and pending work

CONDITIONAL SYNTAX:
- {{#section}}...{{/section}} - Render block only if section has data
- {{#items}}...{{/items}} - Iterate over list items
- {{variable}} - Simple value substitution

ACTION LINKS:
- [Approve](cmd:approve {{id}}) - Triggers approval command
- [Deny](cmd:deny {{id}}) - Triggers denial command

TARGET OUTPUT:
- 25-30 lines maximum when all sections render
- Empty sections collapse completely (not shown)
- One-screen readable for quick CEO review

DATA SOURCES:
- blockers: .worker/approvals/pending/*.json
- overnight: .worker/dispatch/dispatch.jsonl (since last briefing)
- health: .worker/violations/trust-scores.json
- progress: .planning/STATE.md
- outlook: .worker/dispatch/queue.jsonl, .worker/agents/

RENDERING:
The generate-briefing.sh script renders this template dynamically.
For manual rendering, substitute {{variables}} with actual values.
-->

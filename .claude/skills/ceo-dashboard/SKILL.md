---
name: dashboard
description: Show executive dashboard with agent status, trust health, pending approvals, and recent completions. Use when CEO asks about status, progress, what's happening, or what needs attention.
allowed-tools: Read, Bash
context: fork
---

# CEO Dashboard Skill

Display the executive dashboard showing real-time agent status and project health.

## Execution

1. Run the aggregation script to collect current metrics:
   ```bash
   bash .claude/skills/ceo-dashboard/scripts/aggregate-status.sh
   ```

2. If the script doesn't exist yet, manually aggregate from these sources:
   - `.worker/agents/` - Active agent registry and status
   - `.worker/violations/trust-scores.json` - Trust health per agent
   - `.worker/approvals/pending/` - Pending high-stakes approvals
   - `.planning/STATE.md` - Project velocity and progress
   - GitHub issues with `worker-*` labels - Recent completions

## Dashboard Sections

Present the dashboard with these five sections in order:

### 1. Agent Status
Current state of all active agents:
- Agent ID and assigned task
- Runtime duration
- Current status: [ACTIVE], [IDLE], [BLOCKED], [COMPLETE]

### 2. Trust Health
Trust levels and violation status per agent:
- Current trust level (0-4)
- Violation points (decay indicator)
- Recent trust events (promotions/demotions)

### 3. Project Velocity
Phase and plan progress:
- Current phase completion percentage
- Plans completed today/this session
- Average plan duration trend

### 4. Pending Approvals
High-stakes actions awaiting CEO decision:
- Approval ID and request type
- Requesting agent and reason
- Time until auto-deny timeout
- Quick action: [Approve] [Deny] links

### 5. Recent Completions
Last 5 completed tasks:
- Task name and completion time
- Agent that completed it
- Outcome: success/partial/failed

## Output Format

Present as ASCII dashboard with box-drawing characters:

```
+------------------+-------------------+
|   AGENT STATUS   |   TRUST HEALTH    |
+------------------+-------------------+
| [ACTIVE] agent-1 | L3 Trust (0 pts)  |
| [IDLE]   agent-2 | L2 Trust (5 pts)  |
+------------------+-------------------+
|        PROJECT VELOCITY              |
+--------------------------------------+
| Phase 7: [=====>    ] 50%            |
| Plans today: 3 | Avg: 4.2min         |
+--------------------------------------+
|       PENDING APPROVALS (2)          |
+--------------------------------------+
| APR-001: Deploy to prod (15m left)   |
| APR-002: Delete branch (8m left)     |
+--------------------------------------+
|       RECENT COMPLETIONS             |
+--------------------------------------+
| [OK] 07-01: Skill infrastructure     |
| [OK] 06-07: Gap closure              |
+--------------------------------------+
         Last refresh: 2026-01-29 06:45
         Cache age: Live | Metrics: 2m
```

## Cache Behavior

- **Agent status**: Always fetched live (critical for decision-making)
- **Trust health**: Live fetch (security-sensitive)
- **Project velocity**: 5-minute cache (stable metrics)
- **Pending approvals**: Live fetch (time-sensitive)
- **Recent completions**: 5-minute cache (stable data)

Include cache age indicator in footer showing data freshness.

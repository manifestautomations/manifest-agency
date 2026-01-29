# CEO Interface

Executive dashboard, approval workflow, and daily briefings for Manifest Automations.

## Prerequisites

- Claude Code installed with CLI (`claude` command available)
- Repository cloned with `.worker/` directory initialized
- jq installed for JSON parsing

## Quick Start

Three commands for CEO interaction:

| Command | Purpose | Example |
|---------|---------|---------|
| `/dashboard` | Real-time status of agents, trust, velocity | View what's happening now |
| `/briefing` | Daily briefing with blockers and progress | Start of day overview |
| `/approve` | Handle pending approval requests | Approve agent promotions |

## Commands

### /dashboard

Shows executive overview with five sections:

```
+-----------------------------------------------------------+
|  EXECUTIVE DASHBOARD                        Refresh [R]    |
+-----------------------------------------------------------+
|  AGENTS          |  PROJECT VELOCITY   |  TRUST HEALTH    |
|  [OK] 2 Running  |  [========  ] 87%   |  Avg: Level 2    |
|  [!!] 1 Blocked  |  27/31 plans done   |  1 warning       |
|  [--] 0 Idle     |  4.3 min/task avg   |  0 demotions     |
+-----------------------------------------------------------+
|  NEEDS ATTENTION                                           |
|  - backend-developer awaiting approval (PR #42)            |
|  - test-agent: 55 violation points (threshold: 60)         |
+-----------------------------------------------------------+
|  RECENT COMPLETIONS                                        |
|  [OK] Phase 6: Worker Parallelization (32 min)            |
|  [OK] 7 plans executed today                               |
+-----------------------------------------------------------+
```

**Sections:**
1. **Agent Status** - Running, blocked, idle counts with status icons
2. **Project Velocity** - Progress bar, completion percentage, avg task time
3. **Trust Health** - Average trust level, warning/demotion counts
4. **Needs Attention** - Items requiring CEO action
5. **Recent Completions** - Latest completed work

**Data freshness:**
- Agent status: Always live
- Trust health: Always live
- Pending approvals: Always live
- Project velocity: 5-minute cache
- Recent completions: 5-minute cache

### /briefing

Generates daily briefing with five sections in priority order:

1. **Blockers** - Pending approvals requiring action
   - Shows type, agent, time remaining
   - Inline approve/deny action links

2. **Overnight Summary** - Activity since last briefing
   - Completions and failures
   - Trust events (promotions, demotions)
   - Milestones reached

3. **Health Indicators** - System health (only shown if issues exist)
   - Average trust level
   - Warning/critical counts
   - Violation trends

4. **Progress Snapshot** - Always shown
   - Project completion percentage
   - Current velocity
   - Active phase

5. **Today's Outlook** - Queued work (only shown if items exist)
   - Queued items count
   - Pending approvals
   - Expected completions

**Features:**
- Empty sections automatically collapse
- Target length: 25-30 lines (one screen)
- Archived to `.worker/briefings/history/YYYY-MM-DD.md`
- 30-day retention for trend analysis
- Delivered to Inbox automatically (one per day)

### /approve

Handles high-stakes approval requests from agents.

**List pending approvals:**
```bash
# In Claude Code, run /approve with no arguments
# Behind the scenes:
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh list
```

**View approval context:**
```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh context APPROVAL_ID
```

**Approve a request:**
```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh approve APPROVAL_ID "justification"
```

**Deny a request:**
```bash
bash .claude/skills/ceo-dashboard/scripts/approval-workflow.sh deny APPROVAL_ID "reason"
```

## Approval Types

| Type | Auto-Deny | Delegatable | When Triggered |
|------|-----------|-------------|----------------|
| `trust_promotion` | 24h | Level 2 only | Agent requests higher trust level |
| `critical_violation` | Never | No | Agent triggers critical guardrail (security) |
| `scope_access` | 24h | Yes | Agent requests expanded file/directory access |
| `cross_workspace` | 24h | Yes | Agent requests cross-project operation |

### Approval Workflow

```
Agent Request
     |
     v
+---------------+
| Create Pending|---> Inbox notification (immediate for critical)
| Approval      |
+---------------+
     |
     v
+---------------+     +------------------+
| CEO Reviews   |---->| Approve/Deny     |
| via /approve  |     +------------------+
+---------------+            |
     |                       v
     |               +---------------+
     |               | Log to audit  |
     |               | chain         |
     |               +---------------+
     v                       |
+---------------+            v
| Auto-deny     |     +---------------+
| after timeout |     | Notify agent  |
| (except crit) |     | of decision   |
+---------------+     +---------------+
```

### Timeout Rules

- **Standard approvals**: Auto-denied after 24 hours
- **Stale warning**: After 2 hours, approval shows "STALE" indicator
- **Critical violations**: Never auto-deny (must be manually decided)

### Delegation (Optional)

Delegation is disabled by default. When enabled:

```json
// .worker/config.json
"delegation": {
  "enabled": true,
  "delegates": ["delegate-user-id"],
  "allowed_types": ["scope_access", "cross_workspace"]
}
```

**Non-delegatable types:**
- `trust_promotion` (except Level 2)
- `critical_violation`

All delegated approvals are logged with both delegator and delegate for audit.

## Configuration

Settings in `.worker/config.json`:

```json
{
  "ceo_interface": {
    "dashboard": {
      "cache_ttl_seconds": 300,
      "live_metrics": ["agents.running", "agents.blocked", "approvals.pending"]
    },
    "approvals": {
      "timeout_hours": 24,
      "stale_warning_hours": 2,
      "critical_violation_timeout": null
    },
    "briefing": {
      "default_time": "08:00",
      "max_lines": 30,
      "retention_days": 30
    },
    "delegation": {
      "enabled": false,
      "delegates": [],
      "allowed_types": ["scope_access"]
    },
    "notification_tiers": {
      "critical_violation": "immediate",
      "system_down": "immediate",
      "blocked_agent": "delayed",
      "stale_approval": "delayed",
      "briefing": "silent",
      "completion": "silent",
      "trust_change": "silent"
    },
    "ceo_mode": "normal",
    "delayed_threshold_minutes": 120
  }
}
```

### Configuration Options

| Setting | Description | Default |
|---------|-------------|---------|
| `cache_ttl_seconds` | Cache lifetime for stable metrics | 300 (5 min) |
| `timeout_hours` | Time before auto-deny | 24 |
| `stale_warning_hours` | Time before stale indicator | 2 |
| `critical_violation_timeout` | Timeout for critical violations | null (never) |
| `default_time` | Default briefing time | 08:00 |
| `max_lines` | Max briefing length | 30 |
| `retention_days` | Briefing archive retention | 30 |
| `ceo_mode` | Notification mode (dnd/normal/verbose) | normal |

### Notification Tiers

| Tier | Behavior | Events |
|------|----------|--------|
| `immediate` | Push notification | critical_violation, system_down |
| `delayed` | Batched every 2h | blocked_agent, stale_approval |
| `silent` | No push, visible in Inbox | briefing, completion, trust_change |

### CEO Modes

| Mode | Receives |
|------|----------|
| `dnd` | Immediate only (critical violations, system down) |
| `normal` | Immediate + delayed |
| `verbose` | All notifications |

## Inbox Integration

The CEO interface integrates with the Mission Control Inbox:

### Briefings
- Automatically delivered to Inbox conversation
- One briefing per day (duplicate protection)
- Manual `/briefing` also delivers to Inbox

### Approval Requests
- Appear as Inbox messages with action buttons
- Action button format: `action://approve?id=APPROVAL_ID`
- Clicking approve/deny triggers the workflow

### Blocked Agent Badge
- Dashboard blocked count appears as Inbox badge
- Shows number of blocked agents needing attention

## Directory Structure

```
.claude/skills/ceo-dashboard/
  SKILL.md              # Dashboard skill definition
  briefing.SKILL.md     # Briefing skill definition
  approve.SKILL.md      # Approval skill definition
  scripts/
    aggregate-status.sh  # Collect metrics from worker directories
    render-dashboard.sh  # Render ASCII dashboard
    generate-briefing.sh # Generate daily briefing
    approval-workflow.sh # Handle approval state transitions
  templates/
    dashboard-artifact.md # Dashboard template
    briefing-template.md  # Briefing template

.worker/
  approvals/
    pending/           # Awaiting CEO decision
    approved/          # CEO approved
    denied/            # CEO denied
    registry.jsonl     # Audit log of all transitions
  briefings/
    history/           # Archived briefings (30 days)
    last-timestamp.txt # Last briefing time
  inbox/               # Inbox messages
  cache/               # Cached metrics
```

## Troubleshooting

### Dashboard shows all zeros
- Check `.worker/` directory exists
- Run `bash -c 'source .claude/skills/ceo-dashboard/scripts/aggregate-status.sh'` manually
- Check for error messages in output

### Briefing fails to generate
- Check `.worker/briefings/` directory permissions
- Verify jq is installed: `which jq`
- Run manually: `bash .claude/skills/ceo-dashboard/scripts/generate-briefing.sh /tmp/test.md`

### Approval not found
- Approval may have been auto-denied (check timeout)
- Approval may have been processed already
- Check `.worker/approvals/denied/` and `.worker/approvals/approved/`

### Force refresh cached data
```bash
bash -c 'source .claude/skills/ceo-dashboard/scripts/aggregate-status.sh --force'
```

### Check approval audit trail
```bash
cat .worker/approvals/registry.jsonl | jq .
```

### Inbox messages not appearing
- Check `.worker/inbox/` directory exists
- Verify notification tier in config (might be "silent")
- Check `.worker/config.json` ceo_mode setting

## Related Documentation

- [Trust Guardrails](../trust/README.md) - Trust level system
- [Worker System](../worker/README.md) - Agent execution
- [Orchestrator](../orchestrator/README.md) - Multi-agent coordination

---

*Part of the Manifest Automations CEO Interface - Phase 7*

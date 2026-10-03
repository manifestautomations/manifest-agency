---
phase: 07-ceo-interface
plan: 04
subsystem: ceo-dashboard
tags: [bash, briefing, markdown, jq, mustache]
status: complete
dependency-graph:
  requires: ["07-02", "07-03"]
  provides: ["generate-briefing.sh", "briefing-template.md"]
  affects: ["07-05", "07-06"]
tech-stack:
  added: []
  patterns: ["section-collapsing", "timestamp-tracking", "history-archival", "cmd-links"]
key-files:
  created:
    - .claude/skills/ceo-dashboard/scripts/generate-briefing.sh
    - .claude/skills/ceo-dashboard/templates/briefing-template.md
  modified: []
decisions:
  - id: task-consolidation
    description: "Tasks 1 and 2 combined - timestamp tracking integrated into initial script"
  - id: printf-over-echo
    description: "Use printf for consistent section output formatting"
  - id: priority-order
    description: "Five sections: Blockers > Overnight > Health > Progress > Outlook"
metrics:
  duration: 5 min
  tasks: 3
  commits: 2
  completed: 2026-01-29
---

# Phase 07 Plan 04: Briefing Generation Summary

**One-liner:** Daily briefing script generating five-section, one-screen briefings with timestamp tracking, history archival, and actionable approve/deny links.

## What Was Built

### generate-briefing.sh (486 lines)
Comprehensive briefing generation script with five priority sections:

1. **Blockers Section** - Pending approvals requiring CEO action
   - Lists all items from `.worker/approvals/pending/*.json`
   - Shows type, agent, context, and time remaining
   - Includes actionable `[Approve](cmd:approve id)` and `[Deny](cmd:deny id)` links
   - Collapses when no blockers exist

2. **Overnight Section** - Activity since last briefing
   - Counts completions and failures from dispatch log
   - Detects milestones (new SUMMARY.md files)
   - Uses timestamp file for "since last briefing" window
   - Collapses when no overnight activity

3. **Health Section** - Trust anomalies (conditional)
   - Only shown if warnings > 0 or critical > 0
   - Reads from `.worker/violations/trust-scores.json`
   - Trust thresholds: 40-59 = warning, 60+ = critical
   - Provides recommendations for anomalies

4. **Progress Section** - Project completion snapshot (always shown)
   - Extracts completion % from STATE.md
   - Shows current velocity from aggregate-status or STATE.md
   - Displays current phase name

5. **Outlook Section** - Today's queued work (conditional)
   - Counts queued items from dispatch queue
   - Counts pending agents from agents directory
   - Collapses when nothing queued

**Timestamp Tracking:**
- `get_last_briefing_time()` reads `.worker/briefings/last-generated.timestamp`
- Defaults to 24 hours ago on first run
- Updated after each successful generation
- Cross-platform date handling (GNU/BSD)

**History Archival:**
- Archives each briefing to `history/YYYY-MM-DD.md`
- 30-day retention with automatic cleanup
- Supports `--date` flag for historical generation

### briefing-template.md (95 lines)
Mustache-style template documenting the briefing format:

- `{{#section}}...{{/section}}` conditional blocks
- `{{variable}}` simple substitution
- `{{#items}}...{{/items}}` list iteration
- `cmd:` links for approve/deny actions (Antigravity pattern)
- Comprehensive documentation in HTML comments

## Commits

| Hash | Description |
|------|-------------|
| 91a184a | Create generate-briefing.sh with five section generators |
| 71ae6df | Create briefing template with mustache conditionals |

## Key Patterns Established

1. **Section collapsing:**
   ```bash
   local section_content=$(generate_section)
   if [ -n "$section_content" ]; then
     briefing="${briefing}\n${section_content}\n"
   fi
   ```

2. **Action links in briefing:**
   ```markdown
   [Approve](cmd:approve approval-12345) | [Deny](cmd:deny approval-12345)
   ```

3. **Timestamp-based windowing:**
   ```bash
   get_last_briefing_time() {
     if [ -f "$TIMESTAMP_FILE" ]; then
       cat "$TIMESTAMP_FILE"
     else
       # Default: 24 hours ago (cross-platform)
       date -u -d "@$(($(date +%s) - 86400))" +"%Y-%m-%dT%H:%M:%SZ"
     fi
   }
   ```

## Deviations from Plan

### Task Consolidation

**Tasks 1 and 2 combined:**
- Plan specified timestamp tracking as separate Task 2
- Implemented all tracking features in Task 1 for atomic, testable implementation
- Result: 2 commits instead of 3, same functionality

**Rationale:** Timestamp tracking is integral to section generation (Overnight section depends on it). Separating would have created artificial task boundaries.

## Verification Results

- [x] Briefing generates in < 5 seconds (1.2s actual)
- [x] Output is < 30 lines when empty sections collapse (24 lines without blockers)
- [x] Blockers always shown first (priority order verified)
- [x] History archives previous briefings (history/YYYY-MM-DD.md created)
- [x] Timestamp tracking enables "since last briefing" calculations
- [x] Five sections in correct priority order
- [x] Empty sections collapse (not shown in output)
- [x] Actionable approve/deny links in Blockers section
- [x] Briefing fits one screen (30 lines max with all sections)

## Sample Output

```markdown
# Daily Briefing - 2026-01-29

## Blockers

- **trust_promotion** for `test-agent-1`
  - Level 2 to 3 promotion
  - Timeout: 22h 48m | [Approve](cmd:approve approval-test123) | [Deny](cmd:deny approval-test123)

## Overnight Summary

- Completions: 0
- Failures: 2

## Health Indicators

- Average Trust: Level 40
- Warning: 1 agent(s) approaching demotion

## Progress Snapshot

- Project: 94% complete
- Velocity: 4.4 min
- Phase: CEO Interface

## Today's Outlook

- Queued: 0 items
- Pending: 4 items
---
_Generated: 2026-01-29T07:11:50Z_
```

## Next Phase Readiness

Ready for Plan 07-05 (CEO Skill Integration):
- Briefing generation script provides one-screen daily briefings
- Template documents format for reference/rendering
- Action links enable approve/deny workflow integration
- Timestamp tracking enables delta reporting

---

*Completed: 2026-01-29*
*Duration: 5 min*

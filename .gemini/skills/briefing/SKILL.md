---
name: briefing
description: Generate and display daily briefing covering all managed projects with blockers, summaries, and per-project details
---

# Daily Briefing Skill

## Goal

Provide CEO with comprehensive daily briefing covering all managed projects, highlighting blockers and key updates.

## Instructions

1. **Generate briefing:**
   ```bash
   scripts/portfolio/portfolio-briefing.sh
   ```

2. **Check exit code:**
   - 0: Briefing generated successfully
   - 1: Report error with context
   - 2: Escalate to CEO

3. **Read briefing content:**
   ```bash
   cat .worker/briefings/portfolio-latest.md
   ```

4. **Present to CEO:**
   - Lead with blockers (if any)
   - Executive summary (2-3 key points)
   - Per-project details:
     - Recent updates (last 24 hours)
     - Active workers
     - Completed work
     - Blockers
   - Skip empty sections

## Briefing Structure

The briefing follows this format:

```markdown
# Portfolio Briefing - YYYY-MM-DD

## Blockers

[Critical items needing CEO attention]
[Collapses if empty]

## Executive Summary

- [Key point 1]
- [Key point 2]
- [Key point 3]

## Project: [Workspace Name]

**Recent Updates:**
- [Update 1]
- [Update 2]

**Active Work:**
- #N: [Title] (status)

**Completed:**
- #N: [Title]

**Blockers:**
- [Blocker details]

[Repeat for each project with updates]
```

## Presentation Tips

1. **Prioritize blockers:**
   - Present blockers first
   - Include resolution options
   - Show cascade impact

2. **Highlight actionable items:**
   - Approvals needed
   - Decisions required
   - Failed workers needing retry/abandon

3. **Provide context:**
   - Link to issues
   - Show recent activity timeframes
   - Surface frecency patterns (active vs. idle projects)

## Frequency

- Recommended: Daily (morning)
- On-demand: When CEO requests "briefing"
- Automatic: Available via Agent Manager Inbox

## Constraints

- Read-only operation (no state changes)
- 24-hour update window
- Briefing cached in .worker/briefings/
- Projects with no updates omitted for focus

---
name: status
description: Show orchestration dashboard with active worker status and aggregate metrics across all workspaces
---

# Status Dashboard Skill

## Goal

Provide CEO with current state of all active workers and pending items.

## Instructions

1. **Determine scope:**
   - Default: active workers (worker:* labels)
   - If CEO says "all": include closed issues
   - If CEO says "phase N": filter to phase
   - If CEO says "portfolio": use portfolio-dashboard.sh

2. **Run aggregation:**
   ```bash
   scripts/orchestrator/aggregate.sh --format table --scope active
   ```

3. **Check exit code:**
   - 0: Parse stdout, present table
   - 1: Report error, suggest retry
   - 2: Escalate to CEO with context

4. **Present with status icons:**
   ```
   Status | Issue  | Title                        | Updated
   -------|--------|------------------------------|--------
   [..]   | #52    | Foundation - Theme system    | 2m ago
   [??]   | #53    | Dark mode for dashboard      | 5m ago
   [XX]   | #54    | Dark mode for settings       | 8m ago
   ```

   Icon meanings:
   - [..] = executing
   - [??] = awaiting approval
   - [OK] = complete
   - [XX] = failed
   - [--] = partial

5. **Surface actionable items:**
   - [??] = "Issue #N awaiting approval. Review plan?"
   - [XX] = "Issue #N failed. Options: retry, modify, abandon"
   - Blocked = "Issue #N blocked by #M"

## Portfolio View

For portfolio-level status across all workspaces:

```bash
scripts/portfolio/portfolio-dashboard.sh
```

Output includes:
- Aggregate metrics (active workers, completions, failures)
- Per-workspace status
- Needs Attention section (approvals, failures, blockers)
- Recent activity (last 24 hours)

## Constraints

- Never modify GitHub state (read-only)
- Always show issue numbers for reference
- Group by status for clarity
- Cache results for 5 minutes (avoid rate limiting)

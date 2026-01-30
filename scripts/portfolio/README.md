# Portfolio Scripts

Scripts for aggregating and displaying status across all managed workspaces.

## Scripts

### portfolio-status.sh

Collects status data from all registered workspaces.

**Usage:**
```bash
# Get JSON status (default)
bash scripts/portfolio/portfolio-status.sh

# Force refresh (skip cache)
bash scripts/portfolio/portfolio-status.sh --force

# Get only needs-attention items
bash scripts/portfolio/portfolio-status.sh --needs-attention
```

**Output format:**
```json
{
  "workspaces": [
    {
      "name": "project-name",
      "path": "projects/project-name",
      "health": "GREEN|YELLOW|RED",
      "frecency": 42,
      "pending": 0,
      "last_activity": 1234567890
    }
  ],
  "timestamp": "2026-01-30T12:00:00Z"
}
```

**Health status:**
- GREEN: Healthy workspace, recent activity
- YELLOW: Stale (no activity for 3+ days) OR has warnings
- RED: Trust violations OR broken workspace state

**Sourcing:**
```bash
source scripts/portfolio/portfolio-status.sh
data=$(collect_portfolio_status)
```

### portfolio-dashboard.sh

Renders ASCII dashboard from portfolio status.

**Usage:**
```bash
# Display dashboard
bash scripts/portfolio/portfolio-dashboard.sh

# Output to file
bash scripts/portfolio/portfolio-dashboard.sh -o dashboard.md

# Force refresh
bash scripts/portfolio/portfolio-dashboard.sh --force

# Disable colors
bash scripts/portfolio/portfolio-dashboard.sh --no-color
```

**Dashboard sections:**
1. **Needs Attention** - Projects with RED health or pending items (collapses if empty)
2. **All Projects** - Full project list sorted by frecency

## Dependencies

- scripts/workspace/workspace-list.sh
- scripts/workspace/workspace-health.sh
- scripts/workspace/workspace-frecency.sh
- jq (JSON processing)

## Cache

Portfolio status is cached in `.worker/cache/portfolio-cache.json` with 5-minute TTL.
Use `--force` to bypass cache.

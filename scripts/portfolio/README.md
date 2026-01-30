# Portfolio Management Scripts

Scripts for managing and monitoring multiple workspace portfolios.

## Scripts

### portfolio-status.sh

Aggregates status across all registered workspaces with caching.

**Usage:**
```bash
# Get portfolio status (uses cache if valid)
bash scripts/portfolio/portfolio-status.sh

# Force refresh (ignore cache)
bash scripts/portfolio/portfolio-status.sh --force

# Get workspaces needing attention
bash scripts/portfolio/portfolio-status.sh --needs-attention
```

**Output format:**
```json
{
  "workspaces": [
    {
      "name": "workspace-name",
      "path": "projects/workspace-name",
      "health": "GREEN|YELLOW|RED",
      "frecency": 42,
      "pending": 0,
      "last_activity": 1769747037
    }
  ],
  "timestamp": "2026-01-30T12:00:00Z"
}
```

**Health status:**
- **GREEN** - Healthy, no issues
- **YELLOW** - Warnings present (stale or minor issues)
- **RED** - Blocking issues, needs attention

**Cache:**
- Location: `.worker/cache/portfolio-cache.json`
- TTL: 300 seconds (5 minutes)

**Sourcing:**
```bash
source scripts/portfolio/portfolio-status.sh
portfolio_data=$(collect_portfolio_status)
needs_attention=$(get_needs_attention "$portfolio_data")
```

### portfolio-briefing.sh

Generates unified daily briefing covering all managed workspaces.

**Usage:**
```bash
# Generate briefing (default output)
bash scripts/portfolio/portfolio-briefing.sh

# Custom output path
bash scripts/portfolio/portfolio-briefing.sh /path/to/output.md

# Generate for specific date
bash scripts/portfolio/portfolio-briefing.sh --date 2026-01-30
```

**Briefing structure:**
1. **Blockers** - Pending approvals and RED health across all projects (collapses if empty)
2. **Executive Summary** - Projects with/without updates, attention needed
3. **Per-Project Sections** - Details for projects with updates only

**Output location:** `.worker/briefings/portfolio-latest.md`

**History:** Previous briefings archived to `.worker/briefings/history/`

**Sourcing:**
```bash
source scripts/portfolio/portfolio-briefing.sh
generate_portfolio_briefing "/custom/path.md"
```

## Dependencies

Portfolio scripts require:
- `scripts/workspace/workspace-list.sh` - Workspace enumeration
- `scripts/workspace/workspace-health.sh` - Health status checks
- `scripts/workspace/workspace-frecency.sh` - Usage-based scoring

## Architecture

**Portfolio Status Flow:**
```
workspace-list → workspace-health → workspace-frecency
                        ↓
                portfolio-status (cache)
                        ↓
                portfolio-briefing
```

**Caching Strategy:**
- Portfolio status cached for 5 minutes
- Cache invalidated by `--force` flag or age
- Reduces load when multiple consumers query status

**Staleness Detection:**
- Workspaces with no activity >= 3 days promoted to YELLOW health
- Activity determined from dispatch log or git commits
- RED health always overrides staleness

## Integration

**CEO Dashboard:**
Portfolio scripts integrate with CEO dashboard for unified workspace visibility.

**Inbox Integration:**
Briefings can be automatically delivered to inbox with project tagging for notification management.

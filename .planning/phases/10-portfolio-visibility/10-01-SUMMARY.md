---
phase: 10
plan: 01
subsystem: portfolio-aggregation
tags: [portfolio, status, inbox, project-tagging, multi-workspace]
dependencies:
  requires: [09-01, 09-02]
  provides: [portfolio-status-collection, project-aware-inbox]
  affects: [10-02, 10-03, 10-04]
tech-stack:
  added: []
  patterns: [cache-with-ttl, health-staleness-promotion, project-metadata-tagging]
key-files:
  created:
    - scripts/portfolio/portfolio-status.sh
  modified:
    - .claude/skills/ceo-dashboard/inbox-integration.sh
decisions:
  - id: cache-ttl-300
    title: 5-minute cache for portfolio status
    rationale: Balance freshness with performance - portfolio changes infrequently
    alternatives: [no-cache, 1-minute, 10-minute]
  - id: stale-threshold-3days
    title: 3-day threshold for workspace staleness
    rationale: Reasonable window for active development - promotes to YELLOW if no activity
    alternatives: [1-day, 7-days]
  - id: project-optional-field
    title: Project field is optional in inbox metadata
    rationale: Backward compatibility - existing code continues to work without project
    alternatives: [required-field, separate-api]
metrics:
  duration: 4m
  completed: 2026-01-30
---

# Phase 10 Plan 01: Portfolio Status & Project-Tagged Inbox Summary

Portfolio status aggregation collects health, frecency, and pending counts across all workspaces; inbox delivery now supports project tagging for unified visibility.

## What Was Built

### 1. Portfolio Status Aggregation (scripts/portfolio/portfolio-status.sh)

**Purpose:** Collect and aggregate status data from all registered workspaces into a single JSON view.

**Key capabilities:**
- Sources workspace-list, workspace-health, workspace-frecency for data collection
- Collects health status (GREEN/YELLOW/RED) per workspace
- Calculates frecency scores for usage-based ranking
- Counts pending inbox items per workspace
- Tracks last activity timestamp (dispatch log or git log)
- Implements staleness detection (3+ days promotes to YELLOW health)
- 5-minute cache with TTL validation (cross-platform mtime)
- Outputs JSON sorted by frecency descending

**Functions exported:**
- `collect_portfolio_status()` - Main aggregation function
- `get_needs_attention()` - Filter for workspaces needing attention (RED health or pending > 0)
- `is_workspace_stale()` - Check if workspace is stale (>= 3 days)
- `get_workspace_last_activity()` - Get last activity epoch timestamp
- `is_portfolio_cache_valid()` - Check cache validity

**CLI interface:**
- `--force` - Bypass cache, force refresh
- `--json` - Output raw JSON (default)
- `--needs-attention` - Output only workspaces needing attention

**Cache behavior:**
- Location: `.worker/cache/portfolio-cache.json`
- TTL: 300 seconds (5 minutes)
- Invalidated by: FORCE_REFRESH flag or age > TTL

**Health calculation logic:**
1. Call `check_workspace_health()` for base health (GREEN/YELLOW/RED)
2. If health is RED, keep RED (overrides all)
3. If health is not RED, check staleness:
   - Get last_activity timestamp from dispatch log or git log
   - If >= 3 days old, promote to YELLOW
   - Otherwise, keep original health status

### 2. Project-Tagged Inbox Integration (.claude/skills/ceo-dashboard/inbox-integration.sh)

**Purpose:** Enable project-aware inbox delivery for portfolio-wide notifications.

**Changes to existing functions:**

**deliver_to_inbox(tier, project):**
- Added optional second parameter: `project`
- Includes `project: $project` in delivery metadata (after tier, before file)
- Only adds project line if non-empty (backward compatible)

**New functions added:**

**deliver_to_inbox_with_project(tier, project, message):**
- Wrapper that calls deliver_to_inbox with project parameter
- Usage: `echo "msg" | deliver_to_inbox_with_project "delayed" "ProjectName"`

**format_inbox_subject_with_project(project, subject):**
- Adds project prefix to subjects: `[ProjectName] Subject`
- Returns plain subject if project is empty

**show_inbox_summary():**
- Scans all .md files in inbox directory
- Extracts project from frontmatter (`grep "^project:"`)
- Uses "(none)" for items without project
- Builds project counts using jq
- Displays sorted by count descending
- Shows total item count

**filter_inbox_by_project(project_filter):**
- Lists all inbox items for a specific project
- Returns filepath list

**CLI additions:**
- `summary` - Show inbox summary grouped by project
- `filter <project>` - Filter inbox by project name

**Backward compatibility:**
- All existing usage patterns continue to work
- Project parameter is optional everywhere
- Old calls to `deliver_to_inbox` work without modification

## Architecture Decisions

### Cache Strategy

**Decision:** Implement 5-minute cache with TTL validation

**Reasoning:**
- Portfolio data changes infrequently (workspace health, frecency)
- Reduces load when multiple consumers query status
- 5 minutes balances freshness with performance
- Force refresh available for explicit updates

**Implementation:**
- Cross-platform mtime detection (GNU stat vs BSD stat)
- Cache written atomically after successful collection
- Cache miss triggers full recollection

### Staleness Promotion

**Decision:** Workspaces with no activity >= 3 days promoted to YELLOW health

**Reasoning:**
- Inactive workspaces need visibility but aren't blocking
- 3 days is reasonable for active development cycles
- YELLOW signals "check on this" without blocking dispatch
- RED health still overrides staleness (critical issues take priority)

**Implementation:**
- Check dispatch.jsonl for latest timestamp
- Fallback to git log if no dispatch history
- Return 0 if no activity found (treated as stale)

### Project Field Design

**Decision:** Project field is optional metadata, not required

**Reasoning:**
- Preserves backward compatibility with existing code
- Allows gradual adoption across codebase
- Empty project handled gracefully (shows as "(none)" in summary)
- Doesn't break existing inbox delivery flows

**Alternative considered:** Required field would force all callers to update immediately

## Testing & Verification

**Portfolio status:**
- ✓ Script sources without errors
- ✓ Outputs valid JSON with workspaces array
- ✓ Returns empty array when no workspaces registered
- ✓ Cache created at `.worker/cache/portfolio-cache.json`

**Inbox integration:**
- ✓ Sources without errors (no duplicate sourcing)
- ✓ Old usage works: `echo "msg" | deliver silent`
- ✓ New usage works: `echo "msg" | deliver silent "ProjectX"`
- ✓ Summary shows per-project counts
- ✓ Filter returns matching files

**Backward compatibility:**
- ✓ Existing inbox delivery code unchanged
- ✓ format_inbox_message works without project
- ✓ format_approval_request works without project
- ✓ Queued messages handled correctly

## Deviations from Plan

None - plan executed exactly as written.

## Integration Points

**Downstream consumers (will be built in subsequent plans):**

**10-02 (CEO Dashboard Status View):**
- Calls `collect_portfolio_status()` to populate dashboard
- Uses health colors for visual indicators
- Uses frecency for workspace ranking

**10-03 (Multi-Workspace Health Panel):**
- Calls `get_needs_attention()` for attention widget
- Displays RED health workspaces prominently
- Shows pending counts per workspace

**10-04 (Project-Tagged Inbox Notifications):**
- Uses `deliver_to_inbox_with_project()` for dispatch notifications
- Formats subjects with `format_inbox_subject_with_project()`
- Filters inbox by project using `filter_inbox_by_project()`

**Upstream dependencies:**
- `workspace-list.sh` - Provides registered workspace enumeration
- `workspace-health.sh` - Provides health status per workspace
- `workspace-frecency.sh` - Provides usage-based scoring

## Next Phase Readiness

**Ready for 10-02:** Dashboard view implementation can now source portfolio-status.sh and render aggregated data.

**Blockers:** None

**Considerations:**
- Dashboard will need to handle empty workspaces array gracefully
- Consider adding portfolio-level health rollup (e.g., "3 of 5 workspaces healthy")
- May want to add trend data (health history) in future iterations

## Files Changed

**Created:**
- `scripts/portfolio/portfolio-status.sh` (368 lines)

**Modified:**
- `.claude/skills/ceo-dashboard/inbox-integration.sh` (+159 lines, -8 lines)

**Total:** 519 lines added across 2 files

## Commit Log

| Task | Commit | Message |
|------|--------|---------|
| 1 | c510760 | feat(10-01): create portfolio status aggregation script |
| 2 | 67703fe | feat(10-01): extend inbox integration with project tagging |

## Lessons Learned

**1. CEO mode affects delivery testing**
- Silent tier messages are queued, not delivered immediately
- Testing required immediate tier or sourcing to verify functionality
- Real usage will depend on CEO mode configuration

**2. Cross-platform compatibility matters**
- mtime extraction differs (GNU stat vs BSD stat)
- ISO8601 date parsing differs (GNU date vs BSD date)
- Always provide fallback for platform-specific commands

**3. Backward compatibility is valuable**
- Optional parameters allow gradual adoption
- Existing code continues to work without modification
- Reduces risk when extending stable APIs

---
phase: 10
plan: 03
subsystem: portfolio-briefing
tags: [portfolio, briefing, multi-project, executive-summary, blockers]
dependencies:
  requires: [10-01]
  provides: [portfolio-briefing-generation, multi-project-view]
  affects: [10-04]
tech-stack:
  added: []
  patterns: [collapsible-sections, update-detection, briefing-archival]
key-files:
  created:
    - scripts/portfolio/portfolio-briefing.sh
    - scripts/portfolio/README.md
  modified: []
decisions:
  - id: blockers-collapse-if-empty
    title: Blockers section collapses when empty
    rationale: Clean briefing - only show issues when they exist
    alternatives: [always-show-section, remove-section-header]
  - id: updates-24hour-window
    title: 24-hour window for update detection
    rationale: Reasonable timeframe for daily briefing - matches briefing cadence
    alternatives: [since-last-briefing, configurable-window]
  - id: project-sections-only-with-updates
    title: Per-project sections only for projects with updates
    rationale: Focus on active projects - reduces noise for large portfolios
    alternatives: [always-show-all, separate-active-inactive-sections]
metrics:
  duration: 8m
  completed: 2026-01-30
---

# Phase 10 Plan 03: Portfolio Briefing Generation Summary

Multi-project briefing generation delivers unified daily briefing across all workspaces following Blockers → Summary → Details structure.

## What Was Built

### 1. Portfolio Briefing Generation (scripts/portfolio/portfolio-briefing.sh)

**Purpose:** Generate unified daily briefing covering all managed workspaces in a single document.

**Key capabilities:**
- Sources portfolio-status.sh for workspace aggregation
- Generates briefing in priority order: Blockers → Executive Summary → Per-Project Details
- Collapsible sections (blockers collapse if empty, project sections only for active projects)
- Update detection based on 24-hour window:
  - Recent commits (git log --since="24 hours ago")
  - New SUMMARY.md files (mtime -1)
  - Pending inbox items (mtime -1)
- Cross-platform date utilities (ISO 8601, YYYY-MM-DD, epoch)
- Briefing archival to history directory
- Inbox integration for notification delivery with duplicate prevention

**Blockers section:**
- Collects pending approvals from all workspaces
- Checks for RED health status across portfolio
- Collapses completely if no blockers exist
- Format: `[WorkspaceName] approval-type for agent - context`

**Executive Summary section:**
- Always shown (provides context even when no updates)
- Counts projects with/without updates
- Counts projects needing attention (RED health or pending > 0)

**Per-Project sections:**
- Only included for projects with updates in last 24 hours
- Shows completions count from dispatch log
- Shows pending items count
- Shows current health status
- Projects without updates mentioned in summary count only

**Functions exported:**
- `generate_portfolio_briefing(output_file)` - Main generation function
- `collect_workspace_blockers(workspace_path, workspace_name)` - Get blockers from workspace
- `check_workspace_has_updates(workspace_path)` - Detect updates in last 24 hours
- `generate_blockers_section()` - Generate blockers markdown
- `generate_executive_summary_section()` - Generate summary markdown
- `generate_per_project_sections()` - Generate project details markdown

**CLI interface:**
- No args: generate to default output (.worker/briefings/portfolio-latest.md)
- First arg: custom output path
- `--date YYYY-MM-DD`: generate for specific date (for header)
- `help`: show usage

**Output:**
- Location: `.worker/briefings/portfolio-latest.md`
- History: Previous briefings archived to `.worker/briefings/history/portfolio-YYYY-MM-DD.md`
- Cleanup: Old briefings (>30 days) automatically deleted

**Inbox integration:**
- After generation, delivers notification to inbox (if inbox-integration.sh available)
- Uses tier="briefing" for notification routing
- Duplicate check prevents double-delivery same day
- Non-blocking (errors don't prevent briefing generation)

### 2. Portfolio README Documentation (scripts/portfolio/README.md)

**Purpose:** Comprehensive documentation for portfolio management scripts.

**Contents:**
- **portfolio-status.sh documentation:**
  - Usage examples (default, force refresh, needs-attention)
  - Output format (JSON schema)
  - Health status definitions (GREEN/YELLOW/RED)
  - Cache configuration (location, TTL)
  - Sourcing examples

- **portfolio-briefing.sh documentation:**
  - Usage examples (default, custom output, date-specific)
  - Briefing structure explanation
  - Output location and history archival
  - Sourcing examples

- **Dependencies section:**
  - Lists required scripts (workspace-list, workspace-health, workspace-frecency)

- **Architecture section:**
  - Portfolio status flow diagram
  - Caching strategy explanation
  - Staleness detection logic

- **Integration section:**
  - CEO Dashboard integration
  - Inbox integration

## Architecture Decisions

### Collapsible Sections

**Decision:** Blockers section collapses when no blockers exist; per-project sections only for active projects

**Reasoning:**
- Clean briefing presentation - focus on actionable information
- Large portfolios with many inactive projects would clutter briefing
- Executive Summary always shown to provide context
- Blockers section critical when present, unnecessary when absent

**Implementation:**
- `generate_blockers_section()` returns empty string if no blockers
- `generate_per_project_sections()` checks `has_updates` before including project
- Markdown concatenation only includes non-empty sections

### 24-Hour Update Window

**Decision:** Update detection uses 24-hour lookback window

**Reasoning:**
- Matches daily briefing cadence
- Simple and predictable
- Cross-platform (no complex timestamp parsing)
- Aligns with typical development workflow

**Alternative considered:** Using last briefing timestamp would be more precise but adds complexity and dependency on timestamp file

**Implementation:**
- `git log --since="24 hours ago"` for commit detection
- `find -mtime -1` for file modification detection
- Consistent across all update indicators (commits, summaries, inbox)

### Projects Without Updates

**Decision:** Projects with no updates mentioned as count only, not full sections

**Reasoning:**
- Focus on active projects
- Reduces briefing length for large portfolios
- Count visibility prevents projects from being "forgotten"
- Executive Summary provides portfolio-wide context

**Implementation:**
- `check_workspace_has_updates()` returns true/false
- `generate_per_project_sections()` skips projects where has_updates == false
- `generate_executive_summary_section()` counts both categories

## Testing & Verification

**Briefing generation:**
- ✓ Script sources portfolio-status.sh without errors
- ✓ Generates briefing when sourced and function called
- ✓ Outputs to .worker/briefings/portfolio-latest.md
- ✓ Contains "## Executive Summary" section
- ✓ Executive Summary shows project counts (0/0/0 for empty portfolio)
- ✓ Blockers section collapses when no blockers
- ✓ Previous briefing archived to history
- ✓ Timestamp file updated after generation

**README documentation:**
- ✓ Contains portfolio-briefing.sh section
- ✓ Documents usage, structure, output location
- ✓ Includes sourcing examples
- ✓ Explains briefing structure
- ✓ Documents architecture and dependencies

**Empty portfolio handling:**
- ✓ Generates clean briefing even with zero workspaces
- ✓ No errors when portfolio-status returns empty array
- ✓ Executive Summary shows 0/0/0 counts gracefully

## Deviations from Plan

None - plan executed exactly as written.

## Integration Points

**Upstream dependencies:**
- `scripts/portfolio/portfolio-status.sh` - Provides workspace aggregation
- `.claude/skills/ceo-dashboard/inbox-integration.sh` - Optional inbox delivery

**Downstream consumers (will be built in subsequent plans):**

**10-04 (CEO Dashboard Briefing Widget):**
- Will display portfolio-latest.md content
- May call generate_portfolio_briefing() to refresh on demand
- Uses briefing structure for rendering

**Future enhancements:**
- Trend data (compare to previous briefing)
- Configurable update window
- Briefing templates for different audiences
- Slack/email delivery integration

## Next Phase Readiness

**Ready for 10-04:** Dashboard can now display unified portfolio briefing or trigger generation.

**Blockers:** None

**Considerations:**
- Dashboard may want to refresh briefing on demand (call generate_portfolio_briefing)
- Consider adding trend indicators (up/down arrows for project counts)
- May want configurable briefing format (verbose/compact modes)

## Files Changed

**Created:**
- `scripts/portfolio/portfolio-briefing.sh` (486 lines)
- `scripts/portfolio/README.md` (122 lines)

**Total:** 608 lines added across 2 files

## Commit Log

| Task | Commit | Message |
|------|--------|---------|
| 1 | caa6d46 | feat(10-03): create portfolio briefing generation script |
| 2 | 6e7b41b | docs(10-03): update portfolio README with briefing documentation |

## Lessons Learned

**1. Collapsible sections improve briefing clarity**
- Empty sections add no value to executives
- Conditional section generation keeps briefing focused
- Counts in summary provide visibility without details

**2. Update detection needs multiple signals**
- Commits alone don't capture all activity
- New summaries indicate plan completions
- Pending inbox items show incoming work
- Combined view gives complete picture

**3. Briefing archival is important for trending**
- History enables day-over-day comparison
- Automatic cleanup prevents storage bloat
- Timestamp file enables "since last briefing" features

**4. Non-blocking inbox integration**
- Inbox errors shouldn't prevent briefing generation
- Subshell pattern isolates integration failures
- Duplicate check prevents notification spam

## View Delivered

**VIEW-03: Multi-Project Daily Briefing**
- ✓ Unified briefing across all workspaces
- ✓ Blockers section (collapses if empty)
- ✓ Executive Summary (always shown)
- ✓ Per-project details (only for active projects)
- ✓ Structure: Blockers → Summary → Details
- ✓ Projects without updates mentioned as count only

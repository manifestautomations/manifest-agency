# Phase 10: Portfolio Visibility - Research

**Researched:** 2026-01-29
**Domain:** Multi-workspace aggregation, terminal dashboards, markdown briefing generation, inbox tagging
**Confidence:** HIGH

## Summary

Phase 10 extends existing single-workspace tools (dashboard, briefing, inbox) to aggregate across all managed workspaces, providing the CEO with unified portfolio visibility. The research reveals that the existing infrastructure (workspace-list.sh, workspace-health.sh, workspace-frecency.sh, generate-briefing.sh, render-dashboard.sh, inbox-integration.sh) provides solid building blocks that need workspace-aware extensions rather than replacements.

**Key findings:**
- Existing workspace scripts provide iteration primitives (`list_workspaces --porcelain` returns JSON array)
- Health check infrastructure already supports GREEN/YELLOW/RED status per workspace
- Frecency data provides workspace sorting (most recently active first)
- Briefing generation uses section-based template with conditional collapsing
- Inbox integration supports tiered delivery and project tagging via frontmatter
- Dashboard rendering uses ASCII tables with jq for data aggregation

The implementation approach is to extend existing scripts with workspace-iteration wrappers that aggregate data across workspaces, then modify output formats to include project identification.

**Primary recommendation:** Create new scripts in `scripts/portfolio/` that source existing workspace and dashboard scripts, iterate across workspaces to collect data, then render aggregated views using the established patterns. Modify inbox delivery to include `project` frontmatter field.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash | 4.0+ | Shell scripting for aggregation | Existing codebase uses bash; parameter expansion for arrays |
| jq | 1.6+ | JSON processing and aggregation | Already used throughout; supports `-s` for slurp-mode aggregation |
| Git | 2.13+ | Workspace registry via .gitmodules | Phase 8 established submodules as workspace source |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| workspace-list.sh | N/A | Enumerate registered workspaces | Source of truth for workspace iteration |
| workspace-health.sh | N/A | Per-workspace health status | Health indicator collection |
| workspace-frecency.sh | N/A | Frecency scoring | Sorting workspaces by activity |
| aggregate-status.sh | N/A | Single-workspace status aggregation | Pattern for multi-workspace aggregation |
| generate-briefing.sh | N/A | Briefing generation | Template for multi-project briefing |
| inbox-integration.sh | N/A | Inbox delivery | Extends with project tagging |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bash aggregation | Node.js script | Bash maintains consistency with existing scripts; no new runtime needed |
| ASCII dashboard | TUI library (ncurses) | ASCII tables are simpler, portable, match existing render-dashboard.sh |
| YAML frontmatter | JSON metadata | Markdown frontmatter is already established in inbox items |

**Installation:**
```bash
# No new dependencies - uses existing jq, bash, git
# All patterns build on Phase 8 and Phase 9 scripts
```

## Architecture Patterns

### Recommended Project Structure

```
scripts/
├── workspace/                    # Phase 8 scripts (existing)
│   ├── workspace-list.sh
│   ├── workspace-health.sh
│   ├── workspace-frecency.sh
│   └── ...
├── dispatch/                     # Phase 9 scripts (existing)
│   ├── dispatch-to-workspace.sh
│   └── fuzzy-match.sh
└── portfolio/                    # Phase 10 scripts (NEW)
    ├── portfolio-status.sh       # Aggregate status across workspaces
    ├── portfolio-dashboard.sh    # Render aggregated dashboard
    ├── portfolio-briefing.sh     # Generate multi-project briefing
    └── README.md                 # Documentation

.claude/skills/ceo-dashboard/
├── scripts/
│   ├── aggregate-status.sh       # Existing - single workspace
│   ├── render-dashboard.sh       # Existing - extends for portfolio
│   ├── generate-briefing.sh      # Existing - extends for portfolio
│   └── inbox-integration.sh      # Modify to add project field
└── templates/
    └── briefing-template.md      # Extend with per-project sections
```

### Pattern 1: Workspace Iteration with Data Collection

**What:** Iterate across workspaces, collect data, aggregate into single structure
**When to use:** Portfolio status, dashboard, briefing data collection
**Example:**
```bash
# Source: Adapted from existing workspace-health.sh check_all_workspaces()
collect_portfolio_status() {
    local result='{"workspaces":[]}'
    local workspaces_json
    workspaces_json=$(list_workspaces --porcelain 2>/dev/null || echo "[]")

    # Skip if no workspaces
    [[ "$workspaces_json" == "[]" ]] && echo "$result" && return 0

    while IFS= read -r line; do
        local name path status
        name=$(echo "$line" | jq -r '.name')
        path=$(echo "$line" | jq -r '.path')
        status=$(echo "$line" | jq -r '.status')

        # Skip uninitialized
        [[ "$status" == "not-initialized" ]] && continue

        local full_path="$REPO_ROOT/$path"

        # Check health
        check_workspace_health "$full_path"
        local health="$HEALTH_STATUS"

        # Get frecency score
        local frecency_score
        frecency_score=$(calculate_frecency_score "$name" 2>/dev/null || echo "0")

        # Get pending items count (if workspace has inbox)
        local pending_count=0
        if [[ -d "$full_path/.worker/inbox" ]]; then
            pending_count=$(find "$full_path/.worker/inbox" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
        fi

        # Add to result
        result=$(echo "$result" | jq \
            --arg name "$name" \
            --arg health "$health" \
            --argjson frecency "$frecency_score" \
            --argjson pending "$pending_count" \
            '.workspaces += [{name: $name, health: $health, frecency: $frecency, pending: $pending}]')

    done < <(echo "$workspaces_json" | jq -c '.[]')

    echo "$result"
}
```

### Pattern 2: Frecency-Sorted Dashboard Display

**What:** Sort workspaces by frecency, display "Needs Attention" section first
**When to use:** Portfolio dashboard rendering
**Example:**
```bash
# Source: Adapted from existing render-dashboard.sh
render_portfolio_dashboard() {
    local portfolio_data="$1"

    # Sort workspaces by frecency (descending)
    local sorted_workspaces
    sorted_workspaces=$(echo "$portfolio_data" | jq -c '.workspaces | sort_by(-.frecency)')

    # Identify needs-attention items (RED health or pending > 0)
    local needs_attention
    needs_attention=$(echo "$sorted_workspaces" | jq -c '[.[] | select(.health == "RED" or .pending > 0)]')
    local attention_count
    attention_count=$(echo "$needs_attention" | jq 'length')

    # Render dashboard header
    echo "# Portfolio Dashboard"
    echo ""

    # Render Needs Attention section if any
    if [[ "$attention_count" -gt 0 ]]; then
        echo "## Needs Attention"
        echo ""
        echo "| Project | Health | Pending | Action |"
        echo "|---------|--------|---------|--------|"
        echo "$needs_attention" | jq -r '.[] | "| \(.name) | \(.health) | \(.pending) | [View] |"'
        echo ""
    fi

    # Render all projects summary
    echo "## All Projects"
    echo ""
    echo "| Project | Health | Last Activity | Pending |"
    echo "|---------|--------|---------------|---------|"
    echo "$sorted_workspaces" | jq -r '.[] | "| \(.name) | \(.health) | \(.frecency) | \(.pending) |"'
}
```

### Pattern 3: Multi-Project Briefing with Blockers First

**What:** Generate briefing with blockers across all projects first, then per-project sections
**When to use:** Daily briefing generation
**Example:**
```bash
# Source: Adapted from existing generate-briefing.sh
generate_portfolio_briefing() {
    local briefing="# Portfolio Briefing - $(date +%Y-%m-%d)\n\n"

    # Collect blockers across ALL projects first
    local all_blockers=""
    local projects_with_updates=0
    local projects_no_updates=0

    # Iterate workspaces
    local workspaces_json
    workspaces_json=$(list_workspaces --porcelain 2>/dev/null || echo "[]")

    while IFS= read -r line; do
        local name path
        name=$(echo "$line" | jq -r '.name')
        path=$(echo "$line" | jq -r '.path')
        local full_path="$REPO_ROOT/$path"

        # Check for blockers in this workspace
        local workspace_blockers
        workspace_blockers=$(collect_workspace_blockers "$full_path" "$name")
        if [[ -n "$workspace_blockers" ]]; then
            all_blockers="${all_blockers}${workspace_blockers}\n"
        fi

        # Check if workspace has updates
        local has_updates
        has_updates=$(check_workspace_has_updates "$full_path")
        if [[ "$has_updates" == "true" ]]; then
            projects_with_updates=$((projects_with_updates + 1))
        else
            projects_no_updates=$((projects_no_updates + 1))
        fi
    done < <(echo "$workspaces_json" | jq -c '.[]')

    # Section 1: Blockers (all projects)
    if [[ -n "$all_blockers" ]]; then
        briefing="${briefing}## Blockers\n\n${all_blockers}\n"
    fi

    # Section 2: Executive Summary
    briefing="${briefing}## Executive Summary\n\n"
    briefing="${briefing}- Projects with updates: ${projects_with_updates}\n"
    if [[ "$projects_no_updates" -gt 0 ]]; then
        briefing="${briefing}- Projects with no updates: ${projects_no_updates}\n"
    fi
    briefing="${briefing}\n"

    # Section 3: Per-project details (only for projects with updates)
    # ... per-project sections

    echo -e "$briefing"
}
```

### Pattern 4: Inbox Tagging with Project Field

**What:** Add `project` field to inbox item frontmatter, display as prefix
**When to use:** All inbox deliveries
**Example:**
```bash
# Source: Modified from existing inbox-integration.sh
deliver_to_inbox_with_project() {
    local tier="${1:-silent}"
    local project="${2:-}"
    local message
    message=$(cat)

    # Generate filename with project prefix
    local timestamp
    timestamp=$(date +%s%N)

    # Extract type from message metadata
    local msg_type="message"
    local type_line
    type_line=$(echo "$message" | grep "^type:" | head -1)
    if [[ -n "$type_line" ]]; then
        msg_type=$(echo "$type_line" | sed 's/type: *//')
    fi

    local filename="${timestamp}-${msg_type}.md"
    local filepath="$INBOX_DIR/$filename"

    # Add delivery metadata WITH project field
    local delivery_meta="---
delivered: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
tier: $tier
project: $project
file: $filename
---

"

    # ... rest of delivery logic
}

# Format inbox subject with project prefix
format_inbox_subject() {
    local project="$1"
    local subject="$2"

    if [[ -n "$project" ]]; then
        echo "[$project] $subject"
    else
        echo "$subject"
    fi
}
```

### Pattern 5: Aggregated Inbox with Project Filtering

**What:** Display inbox items with project counts, interactive filtering
**When to use:** Inbox viewing/reading
**Example:**
```bash
# Source: New pattern for portfolio inbox
show_inbox_summary() {
    local inbox_dir="$REPO_ROOT/.worker/inbox"

    # Collect items by project
    local project_counts='{}'
    local all_items=()

    for item in "$inbox_dir"/*.md; do
        [[ -f "$item" ]] || continue

        # Extract project from frontmatter
        local project
        project=$(grep "^project:" "$item" 2>/dev/null | sed 's/project: *//' || echo "")
        [[ -z "$project" ]] && project="(none)"

        # Extract tier for priority sorting
        local tier
        tier=$(grep "^tier:" "$item" 2>/dev/null | sed 's/tier: *//' || echo "silent")

        # Update counts
        project_counts=$(echo "$project_counts" | jq --arg p "$project" '.[$p] = ((.[$p] // 0) + 1)')

        all_items+=("$tier|$project|$item")
    done

    # Display aggregate counts
    echo "## Inbox Summary"
    echo ""
    echo "$project_counts" | jq -r 'to_entries | sort_by(-.value) | .[] | "- \(.key): \(.value) item(s)"'
    echo ""

    # Sort by severity (critical first), then list
    echo "## Items (by severity)"
    echo ""
    printf '%s\n' "${all_items[@]}" | sort -t'|' -k1,1 | while IFS='|' read -r tier project filepath; do
        local subject
        subject=$(grep -m1 "^##" "$filepath" 2>/dev/null | sed 's/^## //' || echo "Notification")
        echo "- [$project] $subject (tier: $tier)"
    done
}
```

### Anti-Patterns to Avoid

- **Duplicating existing scripts:** Extend workspace-list.sh, workspace-health.sh, not rewrite
- **Synchronous per-workspace API calls:** Batch operations where possible; cache results
- **Hard-coded project names:** Always use workspace discovery, not assumptions
- **Ignoring uninitialized workspaces:** Skip gracefully, don't fail the whole operation
- **Breaking existing single-workspace paths:** Keep existing scripts working unchanged

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Workspace enumeration | Custom directory traversal | `list_workspaces --porcelain` | Already handles .gitmodules, status checks |
| Health status | Custom git status parsing | `check_workspace_health()` | Already handles all edge cases |
| Activity ranking | Custom timestamp tracking | `calculate_frecency_score()` | Frecency scoring already implemented |
| JSON aggregation | String concatenation | `jq -s` (slurp mode) | Proper JSON handling |
| Inbox delivery | Custom file creation | `deliver_to_inbox()` | Handles tiers, dedup, CEO mode |
| Section collapsing | Manual conditionals | Existing briefing pattern | Empty sections collapse automatically |

**Key insight:** Phase 10 is primarily integration work. The building blocks exist; the task is composing them into portfolio-wide views while preserving per-workspace functionality.

## Common Pitfalls

### Pitfall 1: Performance Degradation with Many Workspaces

**What goes wrong:** Dashboard takes 10+ seconds with 10+ workspaces
**Why it happens:** Sequential health checks, frecency calculations per workspace
**How to avoid:**
- Cache aggregated portfolio data (5-minute TTL like existing dashboard cache)
- Health check only when workspace accessed, not on every dashboard view
- Background refresh option for large portfolios
**Warning signs:** Dashboard load time increases linearly with workspace count

### Pitfall 2: Stale Cached Health Status

**What goes wrong:** Dashboard shows GREEN but workspace is actually RED
**Why it happens:** Health cached but workspace state changed (e.g., trust violation)
**How to avoid:**
- Cache invalidation on workspace events (dispatch, violation, approval)
- Show cache age indicator: "[CACHED 3min]"
- Force refresh option: `--force` flag
**Warning signs:** Dashboard status doesn't match actual workspace state

### Pitfall 3: Breaking Existing Single-Workspace Flows

**What goes wrong:** Old commands stop working after portfolio scripts added
**Why it happens:** Modifying shared scripts instead of extending them
**How to avoid:**
- Create new scripts in `scripts/portfolio/` that source existing scripts
- Keep existing scripts working unchanged
- Add portfolio features as optional flags or new commands
**Warning signs:** Existing dashboard/briefing commands fail after changes

### Pitfall 4: Inbox Flooding with Multi-Project Notifications

**What goes wrong:** CEO inbox has 50+ items daily across all projects
**Why it happens:** Each project generating independent notifications
**How to avoid:**
- Aggregate similar notifications: "3 completions across 2 projects"
- Use project counts at top before listing individual items
- Severity-based filtering: show critical first regardless of project
**Warning signs:** CEO stops reading inbox due to volume

### Pitfall 5: Inconsistent Project Naming in Inbox

**What goes wrong:** Same project shows as "project-a", "Project-A", "ProjectA"
**Why it happens:** Different scripts normalize names differently
**How to avoid:**
- Always use workspace name from `list_workspaces --porcelain`
- Store canonical name in workspace config
- Normalize on display, not storage
**Warning signs:** Filtering by project misses some items

### Pitfall 6: Missing Context in Aggregated Views

**What goes wrong:** Dashboard shows "3 pending" but no way to see what they are
**Why it happens:** Aggregation loses detail that single-workspace view had
**How to avoid:**
- "Needs Attention" section shows actionable items with enough context
- Drill-down links to per-workspace views
- Hover/expand for additional detail
**Warning signs:** CEO needs to run per-workspace commands to understand dashboard

## Code Examples

Verified patterns from existing codebase:

### Workspace Iteration (from workspace-health.sh)

```bash
# Source: scripts/workspace/workspace-health.sh lines 178-224
check_all_workspaces() {
    local has_red=false

    # Get list of workspaces from workspace-list.sh
    local workspaces_json
    workspaces_json=$(list_workspaces --porcelain 2>/dev/null || echo "[]")

    if [[ "$workspaces_json" == "[]" ]]; then
        echo "No workspaces registered."
        return 0
    fi

    # Parse workspace list and check each
    local name path status
    while IFS= read -r line; do
        name=$(echo "$line" | jq -r '.name')
        path=$(echo "$line" | jq -r '.path')
        status=$(echo "$line" | jq -r '.status')

        local full_path="$REPO_ROOT/$path"

        # Skip if not initialized
        if [[ "$status" == "not-initialized" ]]; then
            continue
        fi

        # Check health
        check_workspace_health "$full_path"

        # ... output formatting
    done < <(echo "$workspaces_json" | jq -c '.[]')
}
```

### Frecency-Based Sorting (from workspace-frecency.sh)

```bash
# Source: scripts/workspace/workspace-frecency.sh lines 154-181
rank_workspaces_by_frecency() {
    # Handle empty or missing frecency log
    if [[ ! -f "$FRECENCY_LOG" ]] || [[ ! -s "$FRECENCY_LOG" ]]; then
        return 0
    fi

    # Get unique workspace_ids
    local workspaces
    workspaces=$(jq -r '.workspace_id' "$FRECENCY_LOG" 2>/dev/null | sort -u) || return 0

    # Calculate score for each and collect results
    local results=""
    while IFS= read -r ws; do
        [[ -z "$ws" ]] && continue
        local score
        score=$(calculate_frecency_score "$ws")
        results+="$score $ws"$'\n'
    done <<< "$workspaces"

    # Sort by score descending and output workspace names only
    echo "$results" | sort -t' ' -k1 -rn | awk '{print $2}' | grep -v '^$'
}
```

### Dashboard Caching (from aggregate-status.sh)

```bash
# Source: .claude/skills/ceo-dashboard/scripts/aggregate-status.sh lines 99-120
CACHE_TTL_SECONDS=300  # 5 minutes

is_cache_valid() {
  if [ "$FORCE_REFRESH" = "true" ]; then
    return 1
  fi

  if [ ! -f "$CACHE_FILE" ]; then
    return 1
  fi

  local cache_mtime
  cache_mtime=$(get_file_mtime "$CACHE_FILE")
  local now
  now=$(get_epoch_seconds)
  local age=$((now - cache_mtime))

  if [ "$age" -lt "$CACHE_TTL_SECONDS" ]; then
    return 0
  fi

  return 1
}
```

### Inbox Delivery with Metadata (from inbox-integration.sh)

```bash
# Source: .claude/skills/ceo-dashboard/inbox-integration.sh lines 319-366
deliver_to_inbox() {
  local tier="${1:-silent}"
  local message
  message=$(cat)

  mkdir -p "$INBOX_DIR"

  local timestamp
  timestamp=$(date +%s%N)

  # Extract type from message metadata
  local msg_type="message"
  local type_line
  type_line=$(echo "$message" | grep "^type:" | head -1)
  if [ -n "$type_line" ]; then
    msg_type=$(echo "$type_line" | sed 's/type: *//')
  fi

  local filename="${timestamp}-${msg_type}.md"
  local filepath="$INBOX_DIR/$filename"

  # Add delivery metadata
  local delivery_meta="---
delivered: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
tier: $tier
file: $filename
---

"
  # ... delivery logic
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-workspace dashboard | Portfolio-aggregated dashboard | Phase 10 | Unified visibility across projects |
| Per-workspace briefing | Multi-project briefing | Phase 10 | Single document covers all projects |
| Untagged inbox items | Project-tagged inbox | Phase 10 | Filtering and aggregation by project |

**Deprecated/outdated:**
- N/A - Phase 10 builds on Phase 8-9 infrastructure without deprecating anything

## Open Questions

Things that couldn't be fully resolved:

1. **Workspace inbox location**
   - What we know: Parent repo has `.worker/inbox/`, per-workspace inbox unclear
   - What's unclear: Should each workspace have its own inbox, or aggregate to parent?
   - Recommendation: Aggregate to parent inbox with `project` field. Per-workspace inbox adds complexity without clear benefit for CEO visibility.

2. **Cross-workspace notification deduplication**
   - What we know: Current dedup is per-identifier per-day
   - What's unclear: Should "same event across 3 workspaces" show 1 or 3 inbox items?
   - Recommendation: Show aggregate ("3 workspaces completed") with expandable detail. Implementation TBD based on usage patterns.

3. **Dashboard refresh strategy**
   - What we know: Current dashboard has 5-minute cache TTL
   - What's unclear: Should portfolio dashboard refresh on-demand or on interval?
   - Recommendation: User decision in CONTEXT.md specifies on-demand only. Implement with `--force` flag for manual refresh.

## Sources

### Primary (HIGH confidence)
- `scripts/workspace/workspace-list.sh` - Workspace enumeration pattern (lines 16-94)
- `scripts/workspace/workspace-health.sh` - Health check pattern (lines 35-144, 170-236)
- `scripts/workspace/workspace-frecency.sh` - Frecency scoring (lines 50-181)
- `.claude/skills/ceo-dashboard/scripts/aggregate-status.sh` - Aggregation pattern (lines 145-391)
- `.claude/skills/ceo-dashboard/scripts/render-dashboard.sh` - Dashboard rendering (lines 50-291)
- `.claude/skills/ceo-dashboard/scripts/generate-briefing.sh` - Briefing generation (lines 159-486)
- `.claude/skills/ceo-dashboard/inbox-integration.sh` - Inbox delivery (lines 319-399)
- `.worker/config.json` - Configuration structure (lines 1-67)

### Secondary (MEDIUM confidence)
- [PrettyTable.sh](https://github.com/jakobwesthoff/prettytable.sh) - ASCII table patterns
- [bash-ascii-table](https://github.com/KrisCien/bash-ascii-table) - Table formatting
- [jq JSON processing](https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/) - JSON aggregation patterns
- [jq merge files guide](https://copyprogramming.com/howto/how-to-merge-json-files-using-jq-or-any-tool) - JSONL aggregation with `-s` slurp mode

### Tertiary (LOW confidence)
- WebSearch results on terminal dashboard patterns (general ecosystem survey)
- WebSearch results on markdown report generation (general patterns, not codebase-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools already used in codebase
- Architecture: HIGH - Patterns derived from existing verified scripts
- Pitfalls: MEDIUM - Based on analogous systems, not Phase 10 specific experience

**Research date:** 2026-01-29
**Valid until:** 2026-02-28 (30 days - infrastructure is stable, no external dependencies)

---

**Research Notes:**
- User decisions from CONTEXT.md constrain implementation:
  - Dashboard sorted by frecency (most recently active first)
  - "Needs Attention" section at top
  - Health: GREEN/YELLOW/RED with staleness = 3+ days inactive
  - Briefing order: Blockers -> Summary -> Details
  - Projects with no updates: count only ("3 projects with no updates")
  - On-demand generation only (no scheduled auto-generation)
  - Inbox: `[ProjectName] subject` prefix AND `project` metadata field
  - Interactive filtering for inbox
  - Severity-based prioritization (critical first regardless of project)
- Claude's discretion areas: exact layout (list vs cards), visual treatment, briefing formatting, filter UI
- Existing scripts should be sourced and extended, not modified

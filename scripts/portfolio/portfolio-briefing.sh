#!/usr/bin/env bash
# portfolio-briefing.sh - Generate unified daily briefing across all managed workspaces
#
# Usage:
#   bash scripts/portfolio/portfolio-briefing.sh                     # Output to .worker/briefings/portfolio-latest.md
#   bash scripts/portfolio/portfolio-briefing.sh /path/out.md       # Custom output path
#   bash scripts/portfolio/portfolio-briefing.sh --date 2026-01-30  # Generate for specific date
#
# Briefing structure (in priority order):
#   1. Blockers - Pending approvals and RED health across all projects (collapses if empty)
#   2. Executive Summary - Projects with/without updates, attention needed
#   3. Per-Project Sections - Details for projects with updates only
#
# Output: Markdown briefing file (unified view of all workspaces)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source portfolio status aggregation
source "$SCRIPT_DIR/portfolio-status.sh" 2>/dev/null || {
    echo "Error: Cannot source portfolio-status.sh" >&2
    exit 1
}

# Output paths
BRIEFINGS_DIR="$REPO_ROOT/.worker/briefings"
HISTORY_DIR="$BRIEFINGS_DIR/history"
OUTPUT_DEFAULT="$BRIEFINGS_DIR/portfolio-latest.md"
TIMESTAMP_FILE="$BRIEFINGS_DIR/portfolio-last-generated.timestamp"

# Parse arguments
OUTPUT="${1:-$OUTPUT_DEFAULT}"
TARGET_DATE=""

# Check for --date flag
for arg in "$@"; do
  case "$arg" in
    --date)
      shift
      TARGET_DATE="${1:-}"
      shift || true
      ;;
    --date=*)
      TARGET_DATE="${arg#*=}"
      ;;
    help|--help|-h)
      cat <<'USAGE'
portfolio-briefing.sh - Generate unified daily briefing across all managed workspaces

USAGE:
  ./scripts/portfolio/portfolio-briefing.sh [output-file] [--date YYYY-MM-DD]

OPTIONS:
  output-file          Custom output path (default: .worker/briefings/portfolio-latest.md)
  --date YYYY-MM-DD    Generate briefing for specific date (for header)
  help                 Show this help

EXAMPLES:
  # Generate briefing (default output)
  ./scripts/portfolio/portfolio-briefing.sh

  # Custom output path
  ./scripts/portfolio/portfolio-briefing.sh /path/to/output.md

  # Generate for specific date
  ./scripts/portfolio/portfolio-briefing.sh --date 2026-01-30

BRIEFING STRUCTURE:
  1. Blockers - Pending approvals and RED health (collapses if empty)
  2. Executive Summary - Projects with/without updates, attention needed
  3. Per-Project Sections - Details for projects with updates only

OUTPUT:
  Location: .worker/briefings/portfolio-latest.md
  History: Previous briefings archived to .worker/briefings/history/
USAGE
      exit 0
      ;;
  esac
done

# If OUTPUT starts with relative path, make it absolute from REPO_ROOT
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$REPO_ROOT/$OUTPUT"
fi

# -----------------------------------------------------------------------------
# Utility Functions (cross-platform date handling)
# -----------------------------------------------------------------------------

# Get current timestamp in ISO 8601 format
get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get current date in YYYY-MM-DD format
get_date() {
  date +%Y-%m-%d
}

# Get current epoch seconds
get_epoch() {
  date +%s
}

# Get last briefing time or default to 24 hours ago
get_last_briefing_time() {
  if [ -f "$TIMESTAMP_FILE" ]; then
    cat "$TIMESTAMP_FILE"
  else
    # Default: 24 hours ago (cross-platform)
    local now_epoch
    now_epoch=$(get_epoch)
    local yesterday_epoch=$((now_epoch - 86400))
    date -u -d "@$yesterday_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
    date -u -r "$yesterday_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
    echo "$(date -u +%Y-%m-%d)T00:00:00Z"
  fi
}

# Update last briefing timestamp
update_briefing_timestamp() {
  mkdir -p "$BRIEFINGS_DIR"
  get_timestamp > "$TIMESTAMP_FILE"
}

# Archive current briefing to history
archive_briefing() {
  local briefing_file="$1"
  [ -f "$briefing_file" ] || return 0

  mkdir -p "$HISTORY_DIR"
  local archive_date
  archive_date=$(get_date)
  cp "$briefing_file" "$HISTORY_DIR/portfolio-${archive_date}.md" 2>/dev/null || true
}

# Clean up old briefings (keep last 30 days)
cleanup_old_briefings() {
  [ -d "$HISTORY_DIR" ] || return 0
  find "$HISTORY_DIR" -name "portfolio-*.md" -mtime +30 -delete 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Workspace Analysis Functions
# -----------------------------------------------------------------------------

# Collect blockers from a single workspace
# Args: $1 = workspace_path, $2 = workspace_name
# Returns: formatted blocker lines or empty string
collect_workspace_blockers() {
    local workspace_path="${1:-}"
    local workspace_name="${2:-}"
    local blockers=""

    if [[ -z "$workspace_path" ]] || [[ -z "$workspace_name" ]]; then
        return 0
    fi

    # Check for pending approvals
    local pending_dir="$workspace_path/.worker/approvals/pending"
    if [[ -d "$pending_dir" ]]; then
        while IFS= read -r approval_file; do
            [[ -f "$approval_file" ]] || continue

            local data
            data=$(cat "$approval_file" 2>/dev/null || echo '{}')

            local approval_type agent_id context
            approval_type=$(echo "$data" | jq -r '.type // "unknown"')
            agent_id=$(echo "$data" | jq -r '.agent_id // "unknown"')
            context=$(echo "$data" | jq -r '.context // {} | if type == "object" then (.reason // .description // "Approval required") else . end')

            blockers="${blockers}- **[${workspace_name}] ${approval_type}** for ${agent_id} - ${context}
"
        done < <(find "$pending_dir" -type f -name "*.json" 2>/dev/null)
    fi

    echo "$blockers"
}

# Check if workspace has updates in last 24 hours
# Args: $1 = workspace_path
# Returns: "true" or "false"
check_workspace_has_updates() {
    local workspace_path="${1:-}"

    if [[ -z "$workspace_path" ]]; then
        echo "false"
        return 0
    fi

    # Get last briefing time
    local last_briefing
    last_briefing=$(get_last_briefing_time)

    # Calculate 24 hours ago epoch
    local cutoff_epoch
    cutoff_epoch=$(($(get_epoch) - 86400))

    # Check for recent commits (last 24 hours)
    if [[ -d "$workspace_path/.git" ]]; then
        local commit_count
        commit_count=$(git -C "$workspace_path" log --since="24 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$commit_count" -gt 0 ]]; then
            echo "true"
            return 0
        fi
    fi

    # Check for new SUMMARY files (modified since last briefing)
    if [[ -d "$workspace_path/.planning" ]]; then
        local summary_count
        summary_count=$(find "$workspace_path/.planning" -name "*-SUMMARY.md" -type f -mtime -1 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$summary_count" -gt 0 ]]; then
            echo "true"
            return 0
        fi
    fi

    # Check for pending inbox items (newly created)
    if [[ -d "$workspace_path/.worker/inbox" ]]; then
        local inbox_count
        inbox_count=$(find "$workspace_path/.worker/inbox" -name "*.md" -type f -mtime -1 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$inbox_count" -gt 0 ]]; then
            echo "true"
            return 0
        fi
    fi

    echo "false"
}

# -----------------------------------------------------------------------------
# Section Generators
# -----------------------------------------------------------------------------

# Section 1: Blockers
# Returns: Markdown section or empty string if no blockers
generate_blockers_section() {
    local portfolio_data
    portfolio_data=$(collect_portfolio_status)

    local all_blockers=""
    local blocker_count=0

    # Iterate all workspaces
    while IFS= read -r workspace; do
        local name path health
        name=$(echo "$workspace" | jq -r '.name')
        path=$(echo "$workspace" | jq -r '.path')
        health=$(echo "$workspace" | jq -r '.health')

        local full_path="$REPO_ROOT/$path"

        # Collect blockers from workspace
        local workspace_blockers
        workspace_blockers=$(collect_workspace_blockers "$full_path" "$name")
        if [[ -n "$workspace_blockers" ]]; then
            all_blockers="${all_blockers}${workspace_blockers}"
            blocker_count=$((blocker_count + 1))
        fi

        # Check for RED health as blocker
        if [[ "$health" == "RED" ]]; then
            all_blockers="${all_blockers}- **[${name}]** RED health - Requires attention
"
            blocker_count=$((blocker_count + 1))
        fi
    done < <(echo "$portfolio_data" | jq -c '.workspaces[]')

    # Return section only if there are blockers
    if [[ "$blocker_count" -gt 0 ]]; then
        echo "## Blockers

${all_blockers}"
    fi
}

# Section 2: Executive Summary
# Returns: Markdown section (always shown)
generate_executive_summary_section() {
    local portfolio_data
    portfolio_data=$(collect_portfolio_status)

    local projects_with_updates=0
    local projects_no_updates=0
    local projects_needing_attention=0

    # Iterate all workspaces
    while IFS= read -r workspace; do
        local name path health pending
        name=$(echo "$workspace" | jq -r '.name')
        path=$(echo "$workspace" | jq -r '.path')
        health=$(echo "$workspace" | jq -r '.health')
        pending=$(echo "$workspace" | jq -r '.pending')

        local full_path="$REPO_ROOT/$path"

        # Check for updates
        local has_updates
        has_updates=$(check_workspace_has_updates "$full_path")
        if [[ "$has_updates" == "true" ]]; then
            projects_with_updates=$((projects_with_updates + 1))
        else
            projects_no_updates=$((projects_no_updates + 1))
        fi

        # Check if needs attention
        if [[ "$health" == "RED" ]] || [[ "$pending" -gt 0 ]]; then
            projects_needing_attention=$((projects_needing_attention + 1))
        fi
    done < <(echo "$portfolio_data" | jq -c '.workspaces[]')

    echo "## Executive Summary

- Projects with updates: ${projects_with_updates}
- Projects with no updates: ${projects_no_updates}
- Projects needing attention: ${projects_needing_attention}
"
}

# Section 3: Per-Project Sections
# Returns: Markdown sections for projects with updates only
generate_per_project_sections() {
    local portfolio_data
    portfolio_data=$(collect_portfolio_status)

    local sections=""
    local has_sections=false

    # Iterate all workspaces
    while IFS= read -r workspace; do
        local name path health pending
        name=$(echo "$workspace" | jq -r '.name')
        path=$(echo "$workspace" | jq -r '.path')
        health=$(echo "$workspace" | jq -r '.health')
        pending=$(echo "$workspace" | jq -r '.pending')

        local full_path="$REPO_ROOT/$path"

        # Only include projects with updates
        local has_updates
        has_updates=$(check_workspace_has_updates "$full_path")
        if [[ "$has_updates" != "true" ]]; then
            continue
        fi

        has_sections=true

        # Count completions from dispatch log (last 24 hours)
        local completions=0
        local dispatch_log="$full_path/.worker/dispatch/dispatch.jsonl"
        if [[ -f "$dispatch_log" ]]; then
            local cutoff_epoch
            cutoff_epoch=$(($(get_epoch) - 86400))
            completions=$(jq -s --argjson cutoff "$cutoff_epoch" '
                map(select(
                    .event_type == "dispatch_complete" and
                    (.data.exit_code // 1) == 0
                )) | length
            ' "$dispatch_log" 2>/dev/null || echo 0)
        fi

        # Build project section
        sections="${sections}### ${name}

- Completions: ${completions}
- Pending: ${pending} items
- Health: ${health}

"
    done < <(echo "$portfolio_data" | jq -c '.workspaces[]')

    # Only return sections if at least one project has updates
    if [[ "$has_sections" == "true" ]]; then
        echo "$sections"
    fi
}

# -----------------------------------------------------------------------------
# Main Function
# -----------------------------------------------------------------------------

generate_portfolio_briefing() {
    local output_file="${1:-$OUTPUT_DEFAULT}"
    local briefing_date

    if [ -n "$TARGET_DATE" ]; then
        briefing_date="$TARGET_DATE"
    else
        briefing_date=$(get_date)
    fi

    # Ensure output directory exists
    mkdir -p "$(dirname "$output_file")"

    # Archive existing briefing before overwriting
    archive_briefing "$output_file"

    # Generate header
    local briefing="# Portfolio Briefing - ${briefing_date}
"

    # Generate sections (in priority order)
    local blockers_section
    blockers_section=$(generate_blockers_section)
    if [ -n "$blockers_section" ]; then
        briefing="${briefing}
${blockers_section}"
    fi

    # Executive Summary (always shown)
    local summary_section
    summary_section=$(generate_executive_summary_section)
    briefing="${briefing}
${summary_section}"

    # Per-Project Sections (only if projects have updates)
    local project_sections
    project_sections=$(generate_per_project_sections)
    if [ -n "$project_sections" ]; then
        briefing="${briefing}
${project_sections}"
    fi

    # Add footer with timestamp
    local timestamp
    timestamp=$(get_timestamp)
    briefing="${briefing}---
_Generated: ${timestamp}_"

    # Write briefing to file
    echo "$briefing" > "$output_file"

    # Update timestamp and cleanup
    update_briefing_timestamp
    cleanup_old_briefings

    echo "[portfolio-briefing] Generated: $output_file"
    echo "[portfolio-briefing] Lines: $(wc -l < "$output_file" | tr -d ' ')"
}

# Export functions for sourcing
export -f generate_portfolio_briefing
export -f collect_workspace_blockers
export -f check_workspace_has_updates
export -f generate_blockers_section
export -f generate_executive_summary_section
export -f generate_per_project_sections

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    # Generate briefing
    generate_portfolio_briefing "$OUTPUT"

    # -----------------------------------------------------------------------------
    # Inbox Integration
    # -----------------------------------------------------------------------------

    # Deliver briefing notification to Inbox conversation (non-blocking)
    INBOX_INTEGRATION_SCRIPT="$REPO_ROOT/.claude/skills/ceo-dashboard/inbox-integration.sh"
    if [ -f "$INBOX_INTEGRATION_SCRIPT" ]; then
        (
            # shellcheck source=/dev/null
            source "$INBOX_INTEGRATION_SCRIPT" 2>/dev/null || exit 0

            # Check for duplicate delivery (prevents double-delivery on manual runs)
            briefing_id="portfolio-briefing-$(get_date)"
            is_duplicate=$(check_duplicate_delivery "$briefing_id" 2>/dev/null || echo "false")

            if [ "$is_duplicate" = "false" ]; then
                # Get notification tier for briefings
                TIER=$(get_notification_tier "briefing" 2>/dev/null || echo "delayed")

                # Format and deliver briefing notification
                format_briefing_notification "$OUTPUT" 2>/dev/null | deliver_to_inbox "$TIER" 2>/dev/null || true
                echo "[portfolio-briefing] Delivered to Inbox (tier: $TIER)" >&2
            else
                echo "[portfolio-briefing] Skipped Inbox delivery (already delivered today)" >&2
            fi
        ) || true
    fi
fi

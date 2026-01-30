#!/usr/bin/env bash
# portfolio-status.sh - Aggregate status across all registered workspaces
# Usage: ./scripts/portfolio/portfolio-status.sh [--force] [--json] [--needs-attention]
#
# Collects health, frecency, and pending counts for all workspaces.
# Provides portfolio-wide visibility and attention prioritization.
#
# Options:
#   --force              Force refresh (ignore cache)
#   --json               Output raw JSON (default)
#   --needs-attention    Output only workspaces needing attention
#   help                 Show usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source dependencies
source "$SCRIPT_DIR/../workspace/workspace-list.sh" 2>/dev/null || {
    echo "Error: Cannot source workspace-list.sh" >&2
    exit 1
}
source "$SCRIPT_DIR/../workspace/workspace-health.sh" 2>/dev/null || {
    echo "Error: Cannot source workspace-health.sh" >&2
    exit 1
}
source "$SCRIPT_DIR/../workspace/workspace-frecency.sh" 2>/dev/null || {
    echo "Error: Cannot source workspace-frecency.sh" >&2
    exit 1
}

# Cache configuration
CACHE_FILE="$REPO_ROOT/.worker/cache/portfolio-cache.json"
CACHE_TTL_SECONDS=300

# Ensure cache directory exists
mkdir -p "$(dirname "$CACHE_FILE")"

# Check if portfolio cache is valid
# Returns: 0 if valid, 1 if invalid
is_portfolio_cache_valid() {
    # Force refresh bypasses cache
    if [[ "${FORCE_REFRESH:-false}" == "true" ]]; then
        return 1
    fi

    # Cache file must exist
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    # Check cache age (cross-platform mtime)
    local cache_mtime
    if cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null); then
        # GNU stat
        :
    elif cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null); then
        # BSD stat (macOS)
        :
    else
        # Cannot determine mtime
        return 1
    fi

    local now
    now=$(date +%s)
    local age=$((now - cache_mtime))

    if [[ $age -lt $CACHE_TTL_SECONDS ]]; then
        return 0
    fi

    return 1
}

# Get last activity timestamp for a workspace
# Args: $1 = workspace path
# Returns: epoch timestamp or 0
get_workspace_last_activity() {
    local workspace_path="${1:-}"

    if [[ -z "$workspace_path" ]]; then
        echo "0"
        return 0
    fi

    # Check dispatch log first
    local dispatch_log="$workspace_path/.worker/dispatch/dispatch.jsonl"
    if [[ -f "$dispatch_log" ]] && [[ -s "$dispatch_log" ]]; then
        # Get latest timestamp from dispatch log
        local latest_ts
        latest_ts=$(tail -1 "$dispatch_log" 2>/dev/null | jq -r '.timestamp // ""' 2>/dev/null)
        if [[ -n "$latest_ts" ]] && [[ "$latest_ts" != "null" ]]; then
            # Parse ISO8601 to epoch
            local epoch
            if date --version >/dev/null 2>&1; then
                # GNU date
                epoch=$(date -d "$latest_ts" +%s 2>/dev/null) || epoch=0
            else
                # BSD date (macOS)
                epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$latest_ts" +%s 2>/dev/null) || epoch=0
            fi
            echo "$epoch"
            return 0
        fi
    fi

    # Fallback to git log
    if [[ -d "$workspace_path/.git" ]]; then
        local git_epoch
        git_epoch=$(git -C "$workspace_path" log --format=%ct -1 2>/dev/null || echo "0")
        echo "$git_epoch"
        return 0
    fi

    # No activity found
    echo "0"
    return 0
}

# Check if workspace is stale (>= 3 days since last activity)
# Args: $1 = last_activity_epoch
# Returns: "true" or "false"
is_workspace_stale() {
    local last_activity_epoch="${1:-0}"

    if [[ "$last_activity_epoch" -eq 0 ]]; then
        echo "true"
        return 0
    fi

    local now
    now=$(date +%s)
    local age_seconds=$((now - last_activity_epoch))
    local age_days=$((age_seconds / 86400))

    if [[ $age_days -ge 3 ]]; then
        echo "true"
    else
        echo "false"
    fi

    return 0
}

# Collect portfolio status across all workspaces
# Returns: JSON with workspaces array
collect_portfolio_status() {
    # Check cache first
    if is_portfolio_cache_valid; then
        cat "$CACHE_FILE"
        return 0
    fi

    # Initialize result
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local result
    result=$(jq -nc --arg ts "$timestamp" '{"workspaces":[],"timestamp":$ts}')

    # Get workspaces list
    local workspaces_json
    workspaces_json=$(list_workspaces --porcelain 2>/dev/null || echo "[]")

    if [[ "$workspaces_json" == "[]" ]]; then
        # No workspaces - return empty result
        echo "$result" | tee "$CACHE_FILE"
        return 0
    fi

    # Process each workspace
    while IFS= read -r line; do
        local name path status
        name=$(echo "$line" | jq -r '.name')
        path=$(echo "$line" | jq -r '.path')
        status=$(echo "$line" | jq -r '.status')

        # Skip if not initialized
        if [[ "$status" == "not-initialized" ]]; then
            continue
        fi

        local full_path="$REPO_ROOT/$path"

        # Check workspace health
        check_workspace_health "$full_path" 2>/dev/null || {
            # Skip workspace if health check fails
            continue
        }

        # Determine display health
        local health_display="$HEALTH_STATUS"
        if [[ "$HEALTH_STATUS" != "RED" ]]; then
            # Check if stale
            local last_activity
            last_activity=$(get_workspace_last_activity "$full_path")
            local is_stale
            is_stale=$(is_workspace_stale "$last_activity")
            if [[ "$is_stale" == "true" ]]; then
                health_display="YELLOW"
            fi
        fi

        # Get frecency score
        local frecency_score
        frecency_score=$(calculate_frecency_score "$name" 2>/dev/null || echo "0")

        # Count pending inbox items
        local pending=0
        local inbox_dir="$full_path/.worker/inbox"
        if [[ -d "$inbox_dir" ]]; then
            pending=$(find "$inbox_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
        fi

        # Get last activity timestamp
        local last_activity
        last_activity=$(get_workspace_last_activity "$full_path")

        # Build workspace object
        local workspace_obj
        workspace_obj=$(jq -nc \
            --arg name "$name" \
            --arg path "$path" \
            --arg health "$health_display" \
            --argjson frecency "$frecency_score" \
            --argjson pending "$pending" \
            --argjson last_activity "$last_activity" \
            '{
                name: $name,
                path: $path,
                health: $health,
                frecency: $frecency,
                pending: $pending,
                last_activity: $last_activity
            }')

        # Append to result
        result=$(echo "$result" | jq --argjson ws "$workspace_obj" '.workspaces += [$ws]')

    done < <(echo "$workspaces_json" | jq -c '.[]')

    # Sort workspaces by frecency descending
    result=$(echo "$result" | jq '.workspaces |= sort_by(-.frecency)')

    # Save to cache
    echo "$result" > "$CACHE_FILE"

    # Output result
    echo "$result"
    return 0
}

# Get workspaces that need attention
# Args: $1 = portfolio_data (JSON)
# Returns: JSON array of workspaces needing attention
get_needs_attention() {
    local portfolio_data="${1:-}"

    if [[ -z "$portfolio_data" ]]; then
        portfolio_data=$(collect_portfolio_status)
    fi

    # Filter workspaces where health == "RED" or pending > 0
    echo "$portfolio_data" | jq '[.workspaces[] | select(.health == "RED" or .pending > 0)]'
    return 0
}

# Export functions for sourcing
export -f is_portfolio_cache_valid
export -f get_workspace_last_activity
export -f is_workspace_stale
export -f collect_portfolio_status
export -f get_needs_attention

# Show usage
_show_usage() {
    cat <<'USAGE'
portfolio-status.sh - Portfolio-wide workspace status aggregation

USAGE:
  ./scripts/portfolio/portfolio-status.sh [options]

OPTIONS:
  --force              Force refresh (ignore cache)
  --json               Output raw JSON (default)
  --needs-attention    Output only workspaces needing attention
  help                 Show this help

EXAMPLES:
  # Get portfolio status (uses cache if valid)
  ./scripts/portfolio/portfolio-status.sh

  # Force refresh
  ./scripts/portfolio/portfolio-status.sh --force

  # Get workspaces needing attention
  ./scripts/portfolio/portfolio-status.sh --needs-attention

OUTPUT FORMAT:
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

HEALTH STATUS:
  GREEN  - Healthy, no issues
  YELLOW - Warnings present (stale or minor issues)
  RED    - Blocking issues, needs attention

CACHE:
  Location: .worker/cache/portfolio-cache.json
  TTL: 300 seconds (5 minutes)
USAGE
}

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    FORCE_REFRESH=false
    OUTPUT_MODE="json"
    NEEDS_ATTENTION=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_REFRESH=true
                shift
                ;;
            --json)
                OUTPUT_MODE="json"
                shift
                ;;
            --needs-attention)
                NEEDS_ATTENTION=true
                shift
                ;;
            help|--help|-h)
                _show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Run '$0 help' for usage information." >&2
                exit 1
                ;;
        esac
    done

    # Collect portfolio status
    if [[ "$NEEDS_ATTENTION" == "true" ]]; then
        # Get full status first, then filter
        portfolio_data=$(collect_portfolio_status)
        get_needs_attention "$portfolio_data"
    else
        # Default: output full portfolio status
        collect_portfolio_status
    fi
fi

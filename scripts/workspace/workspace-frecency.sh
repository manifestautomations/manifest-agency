#!/usr/bin/env bash
# workspace-frecency.sh - Track workspace access patterns using frecency scoring
# Usage: ./scripts/workspace/workspace-frecency.sh [command] [args]
#
# Frecency = frequency * recency (time-weighted access scoring)
# Uses JSONL format for append-only event logging
#
# Commands when run directly:
#   record <workspace_id>    - Record an access event
#   score <workspace_id>     - Calculate frecency score
#   rank                     - List workspaces ranked by frecency

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRECENCY_LOG="$REPO_ROOT/.worker/dispatch/frecency.jsonl"

# Ensure frecency log directory exists
mkdir -p "$(dirname "$FRECENCY_LOG")"

# Record a workspace access event
# Usage: record_workspace_access <workspace_id>
# Appends JSONL event to frecency log
record_workspace_access() {
    local workspace_id="${1:-}"

    if [[ -z "$workspace_id" ]]; then
        echo "Usage: record_workspace_access <workspace_id>" >&2
        return 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Append JSONL event (create file if doesn't exist)
    printf '{"timestamp":"%s","workspace_id":"%s","event":"access"}\n' \
        "$timestamp" "$workspace_id" >> "$FRECENCY_LOG"

    return 0
}

# Calculate frecency score for a workspace
# Usage: calculate_frecency_score <workspace_id>
# Returns: numeric score to stdout (integer)
#
# Scoring algorithm:
#   - Count total visits
#   - Sample last 10 visits for time-decay weights
#   - Weight by age: <5d=100, 5-14d=70, 15-31d=50, 32-89d=30, 90+d=10
#   - Score = visit_count * (average_weight / 100)
calculate_frecency_score() {
    local workspace_id="${1:-}"

    if [[ -z "$workspace_id" ]]; then
        echo "0"
        return 0
    fi

    # Handle empty or missing frecency log
    if [[ ! -f "$FRECENCY_LOG" ]] || [[ ! -s "$FRECENCY_LOG" ]]; then
        echo "0"
        return 0
    fi

    # Get events for this workspace
    local events
    events=$(jq -r --arg ws "$workspace_id" \
        'select(.workspace_id == $ws) | .timestamp' \
        "$FRECENCY_LOG" 2>/dev/null) || {
        echo "0"
        return 0
    }

    if [[ -z "$events" ]]; then
        echo "0"
        return 0
    fi

    # Count total visits
    local visit_count
    visit_count=$(echo "$events" | wc -l | tr -d ' ')

    if [[ "$visit_count" -eq 0 ]]; then
        echo "0"
        return 0
    fi

    # Get last 10 visits for recency weighting
    local recent_timestamps
    recent_timestamps=$(echo "$events" | tail -10)

    # Calculate average weight based on age
    local now_epoch
    now_epoch=$(date +%s)

    local total_weight=0
    local sample_count=0

    while IFS= read -r ts; do
        [[ -z "$ts" ]] && continue

        # Parse ISO8601 timestamp to epoch
        # Handle both GNU date and BSD date
        local ts_epoch
        if date --version >/dev/null 2>&1; then
            # GNU date
            ts_epoch=$(date -d "$ts" +%s 2>/dev/null) || continue
        else
            # BSD date (macOS)
            ts_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null) || continue
        fi

        local age_seconds=$((now_epoch - ts_epoch))
        local age_days=$((age_seconds / 86400))

        # Calculate weight based on age
        local weight
        if [[ $age_days -lt 5 ]]; then
            weight=100
        elif [[ $age_days -lt 15 ]]; then
            weight=70
        elif [[ $age_days -lt 32 ]]; then
            weight=50
        elif [[ $age_days -lt 90 ]]; then
            weight=30
        else
            weight=10
        fi

        total_weight=$((total_weight + weight))
        sample_count=$((sample_count + 1))
    done <<< "$recent_timestamps"

    # Calculate final score
    if [[ $sample_count -eq 0 ]]; then
        echo "0"
        return 0
    fi

    local avg_weight=$((total_weight / sample_count))
    local score=$((visit_count * avg_weight / 100))

    # Ensure minimum score of 1 if there are any visits
    if [[ $score -eq 0 ]] && [[ $visit_count -gt 0 ]]; then
        score=1
    fi

    echo "$score"
    return 0
}

# Rank all workspaces by frecency score
# Usage: rank_workspaces_by_frecency
# Returns: workspace_ids sorted by score (highest first), one per line
rank_workspaces_by_frecency() {
    # Handle empty or missing frecency log
    if [[ ! -f "$FRECENCY_LOG" ]] || [[ ! -s "$FRECENCY_LOG" ]]; then
        return 0
    fi

    # Get unique workspace_ids
    local workspaces
    workspaces=$(jq -r '.workspace_id' "$FRECENCY_LOG" 2>/dev/null | sort -u) || return 0

    if [[ -z "$workspaces" ]]; then
        return 0
    fi

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

    return 0
}

# Export functions for sourcing
export -f record_workspace_access
export -f calculate_frecency_score
export -f rank_workspaces_by_frecency

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    case "${1:-}" in
        record)
            record_workspace_access "${2:-}"
            ;;
        score)
            calculate_frecency_score "${2:-}"
            ;;
        rank)
            rank_workspaces_by_frecency
            ;;
        *)
            echo "Usage: $0 {record|score|rank} [args]" >&2
            echo "  record <workspace_id>  - Record access event" >&2
            echo "  score <workspace_id>   - Get frecency score" >&2
            echo "  rank                   - List workspaces by frecency" >&2
            exit 1
            ;;
    esac
fi

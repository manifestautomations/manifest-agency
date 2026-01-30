#!/usr/bin/env bash
# portfolio-dashboard.sh - Render portfolio dashboard from status data
# Usage: ./scripts/portfolio/portfolio-dashboard.sh [options]
#
# Renders ASCII dashboard showing aggregated status across all projects.
# Displays health indicators, activity levels, and pending counts.
#
# Options:
#   -o FILE, --output FILE   Output to file instead of stdout
#   --force                  Force refresh (skip cache)
#   --no-color               Disable ANSI colors
#   help                     Show usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source portfolio-status.sh
source "$SCRIPT_DIR/portfolio-status.sh" 2>/dev/null || {
    echo "Error: Cannot source portfolio-status.sh" >&2
    exit 1
}

# Color control (can be disabled via --no-color)
USE_COLOR=true

# Format health indicator with color
# Args: $1 = health_status (GREEN, YELLOW, RED)
# Returns: formatted string with color codes
format_health_indicator() {
    local health_status="${1:-}"

    if [[ -z "$health_status" ]]; then
        echo "[??]"
        return 0
    fi

    # Check if terminal supports colors
    local colors=0
    if [[ "$USE_COLOR" == "true" ]]; then
        colors=$(tput colors 2>/dev/null || echo 0)
    fi

    if [[ $colors -ge 8 ]]; then
        # Color output
        case "$health_status" in
            GREEN)
                printf '\033[32m[OK]\033[0m'
                ;;
            YELLOW)
                printf '\033[33m[!!]\033[0m'
                ;;
            RED)
                printf '\033[31m[XX]\033[0m'
                ;;
            *)
                printf '[??]'
                ;;
        esac
    else
        # Plain text output
        case "$health_status" in
            GREEN)
                printf '[OK]'
                ;;
            YELLOW)
                printf '[!!]'
                ;;
            RED)
                printf '[XX]'
                ;;
            *)
                printf '[??]'
                ;;
        esac
    fi

    return 0
}

# Format frecency score for display
# Args: $1 = frecency_score
# Returns: human-readable activity level
format_frecency_display() {
    local frecency_score="${1:-0}"

    if [[ $frecency_score -gt 50 ]]; then
        echo "Active"
    elif [[ $frecency_score -gt 10 ]]; then
        echo "Recent"
    elif [[ $frecency_score -gt 0 ]]; then
        echo "Idle"
    else
        echo "New"
    fi

    return 0
}

# Render "Needs Attention" section
# Args: $1 = portfolio_data JSON
# Returns: markdown table section or empty string
render_needs_attention_section() {
    local portfolio_data="${1:-}"

    if [[ -z "$portfolio_data" ]]; then
        return 0
    fi

    # Extract items where health == "RED" or pending > 0
    local needs_attention
    needs_attention=$(echo "$portfolio_data" | jq -c '[.workspaces[] | select(.health == "RED" or .pending > 0)]')

    local count
    count=$(echo "$needs_attention" | jq 'length')

    if [[ $count -eq 0 ]]; then
        # Section collapses if empty
        return 0
    fi

    # Output section header
    echo "## Needs Attention"
    echo ""
    echo "| Project | Status | Pending | Action |"
    echo "|---------|--------|---------|--------|"

    # Render each item
    echo "$needs_attention" | jq -c '.[]' | while IFS= read -r item; do
        local name health pending
        name=$(echo "$item" | jq -r '.name')
        health=$(echo "$item" | jq -r '.health')
        pending=$(echo "$item" | jq -r '.pending')

        # Format health indicator
        local health_display
        health_display=$(format_health_indicator "$health")

        # Output row
        printf '| %s | %s | %d | [View] |\n' "$name" "$health_display" "$pending"
    done

    echo ""
    return 0
}

# Render "All Projects" section
# Args: $1 = portfolio_data JSON
# Returns: markdown table section
render_all_projects_section() {
    local portfolio_data="${1:-}"

    if [[ -z "$portfolio_data" ]]; then
        echo "No portfolio data available."
        return 0
    fi

    # Extract workspaces array (already sorted by frecency)
    local workspaces
    workspaces=$(echo "$portfolio_data" | jq -c '.workspaces')

    local count
    count=$(echo "$workspaces" | jq 'length')

    if [[ $count -eq 0 ]]; then
        echo "[--] No projects registered."
        return 0
    fi

    # Output section header
    echo "## All Projects"
    echo ""
    echo "| Project | Health | Activity | Pending |"
    echo "|---------|--------|----------|---------|"

    # Render each workspace
    echo "$workspaces" | jq -c '.[]' | while IFS= read -r workspace; do
        local name health frecency pending
        name=$(echo "$workspace" | jq -r '.name')
        health=$(echo "$workspace" | jq -r '.health')
        frecency=$(echo "$workspace" | jq -r '.frecency')
        pending=$(echo "$workspace" | jq -r '.pending')

        # Format health indicator
        local health_display
        health_display=$(format_health_indicator "$health")

        # Format activity level
        local activity_display
        activity_display=$(format_frecency_display "$frecency")

        # Output row
        printf '| %s | %s | %s | %d |\n' "$name" "$health_display" "$activity_display" "$pending"
    done

    echo ""
    return 0
}

# Render portfolio summary line
# Args: $1 = portfolio_data JSON
# Returns: summary string
render_portfolio_summary_line() {
    local portfolio_data="${1:-}"

    if [[ -z "$portfolio_data" ]]; then
        echo "Total: 0 projects | 0 need attention"
        return 0
    fi

    # Count total workspaces
    local total
    total=$(echo "$portfolio_data" | jq '.workspaces | length')

    # Count needs_attention items
    local needs_attention_count
    needs_attention_count=$(echo "$portfolio_data" | jq '[.workspaces[] | select(.health == "RED" or .pending > 0)] | length')

    echo "Total: $total projects | $needs_attention_count need attention"
    return 0
}

# Main render function
# Returns: dashboard markdown output
render_portfolio_dashboard() {
    # Get portfolio data
    local portfolio_data
    if [[ "${FORCE_REFRESH:-false}" == "true" ]]; then
        FORCE_REFRESH=true portfolio_data=$(collect_portfolio_status)
    else
        portfolio_data=$(collect_portfolio_status)
    fi

    # Extract timestamp and cache status
    local timestamp cache_status
    timestamp=$(echo "$portfolio_data" | jq -r '.timestamp // "N/A"')

    # Determine cache status
    if is_portfolio_cache_valid 2>/dev/null; then
        local cache_age
        cache_age=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        local age_seconds=$((now - cache_age))
        local age_min=$((age_seconds / 60))
        cache_status="[CACHED ${age_min}min]"
    else
        cache_status="[LIVE]"
    fi

    # Build dashboard output
    echo "# Portfolio Dashboard"
    echo ""
    echo "\`\`\`"
    echo "+---------------------------------------------------------------+"
    echo "|  PORTFOLIO DASHBOARD                          $cache_status"
    echo "+---------------------------------------------------------------+"
    echo "| Last updated: $timestamp"
    echo "+---------------------------------------------------------------+"
    echo "\`\`\`"
    echo ""

    # Render needs attention section (collapses if empty)
    render_needs_attention_section "$portfolio_data"

    # Render all projects section
    render_all_projects_section "$portfolio_data"

    # Summary line
    local summary
    summary=$(render_portfolio_summary_line "$portfolio_data")
    echo "---"
    echo ""
    echo "$summary"

    return 0
}

# Export functions for sourcing
export -f format_health_indicator
export -f format_frecency_display
export -f render_needs_attention_section
export -f render_all_projects_section
export -f render_portfolio_summary_line
export -f render_portfolio_dashboard

# Show usage
_show_usage() {
    cat <<'USAGE'
portfolio-dashboard.sh - Render portfolio dashboard from status data

USAGE:
  ./scripts/portfolio/portfolio-dashboard.sh [options]

OPTIONS:
  -o FILE, --output FILE   Write output to file instead of stdout
  --force                  Force refresh (skip cache)
  --no-color               Disable ANSI colors
  help                     Show this help

EXAMPLES:
  # Display dashboard
  ./scripts/portfolio/portfolio-dashboard.sh

  # Output to file
  ./scripts/portfolio/portfolio-dashboard.sh -o dashboard.md

  # Force refresh and disable colors
  ./scripts/portfolio/portfolio-dashboard.sh --force --no-color

DASHBOARD SECTIONS:
  1. Needs Attention - Projects with RED health or pending items
  2. All Projects - Full project list sorted by frecency

HEALTH INDICATORS:
  [OK] - GREEN (healthy workspace)
  [!!] - YELLOW (warnings or stale)
  [XX] - RED (blocking issues)

ACTIVITY LEVELS:
  Active  - Frecency score > 50 (very recently used)
  Recent  - Frecency score > 10 (used in last few weeks)
  Idle    - Frecency score > 0 (used, but not recently)
  New     - Frecency score = 0 (never used)
USAGE
}

# Execute if run directly (not sourced)
if [[ ${BASH_SOURCE[0]} == $0 ]]; then
    set -euo pipefail

    OUTPUT_FILE=""
    FORCE_REFRESH=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                OUTPUT_FILE="${2:-}"
                if [[ -z "$OUTPUT_FILE" ]]; then
                    echo "Error: --output requires a filename" >&2
                    exit 1
                fi
                shift 2
                ;;
            --force)
                FORCE_REFRESH=true
                shift
                ;;
            --no-color)
                USE_COLOR=false
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

    # Render dashboard
    if [[ -n "$OUTPUT_FILE" ]]; then
        render_portfolio_dashboard > "$OUTPUT_FILE"
        echo "Dashboard rendered to: $OUTPUT_FILE" >&2
    else
        render_portfolio_dashboard
    fi
fi

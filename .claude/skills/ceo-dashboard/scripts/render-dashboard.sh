#!/usr/bin/env bash
# render-dashboard.sh - Render ASCII dashboard from aggregated data
#
# Usage:
#   bash .claude/skills/ceo-dashboard/scripts/render-dashboard.sh           # Output to stdout
#   bash .claude/skills/ceo-dashboard/scripts/render-dashboard.sh -o file   # Output to file
#
# Renders the dashboard template with real data from aggregate-status.sh
# Handles dynamic sections (approvals, completions) via marker replacement
set -euo pipefail

# Resolve script directory
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(pwd)"
fi

# Paths
TEMPLATE="${SCRIPT_DIR}/../templates/dashboard-artifact.md"
AGGREGATE_SCRIPT="${SCRIPT_DIR}/aggregate-status.sh"

# Navigate to repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [ ! -d "$REPO_ROOT/.worker" ]; then
  REPO_ROOT="$(pwd)"
  while [ ! -d "$REPO_ROOT/.worker" ] && [ "$REPO_ROOT" != "/" ]; do
    REPO_ROOT="$(dirname "$REPO_ROOT")"
  done
fi

# Parse arguments
OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Rendering Functions
# -----------------------------------------------------------------------------

# Render ASCII progress bar (10 chars)
# Input: percent (0-100)
# Output: ASCII bar like "[========= ]"
render_progress_bar() {
  local percent="${1:-0}"

  # Clamp to 0-100
  if [ "$percent" -lt 0 ] 2>/dev/null; then percent=0; fi
  if [ "$percent" -gt 100 ] 2>/dev/null; then percent=100; fi

  # Calculate filled segments (out of 10)
  local filled=$((percent / 10))
  local empty=$((10 - filled))

  # Build bar
  local bar="["
  local i
  for ((i=0; i<filled; i++)); do
    bar="${bar}="
  done
  for ((i=0; i<empty; i++)); do
    bar="${bar} "
  done
  bar="${bar}]"

  printf '%s' "$bar"
}

# Format time remaining for human display
format_time_remaining() {
  local seconds="$1"

  if [ "$seconds" = "infinite" ]; then
    printf '%s' "no timeout"
  elif [ "$seconds" -lt 0 ] 2>/dev/null; then
    printf '%s' "EXPIRED"
  elif [ "$seconds" -lt 3600 ] 2>/dev/null; then
    printf '%s' "$((seconds / 60))m"
  elif [ "$seconds" -lt 86400 ] 2>/dev/null; then
    printf '%s' "$((seconds / 3600))h $((seconds % 3600 / 60))m"
  else
    printf '%s' "$((seconds / 86400))d"
  fi
}

# Render pending approvals as formatted table rows
# Input: JSON array of pending approvals
# Output: Formatted table rows
render_pending_approvals() {
  local approvals_json="$1"
  local count
  count=$(printf '%s' "$approvals_json" | jq 'length')

  if [ "$count" -eq 0 ]; then
    return
  fi

  # Render each approval as table row
  printf '%s' "$approvals_json" | jq -r '.[] | "\(.type // "unknown")|\(.agent_id // "unknown")|\(.time_remaining // "0")|\(.stale_status // "active")"' | while IFS='|' read -r approval_type agent_id time_remaining stale_status; do
    # Determine status icon
    local status_icon="[..]"
    case "$stale_status" in
      stale)   status_icon="[!!]" ;;
      expired) status_icon="[XX]" ;;
      active)  status_icon="[..]" ;;
    esac

    # Format timeout display
    local timeout_display
    timeout_display=$(format_time_remaining "$time_remaining")

    printf '| %s | %s | %s | %s | [Approve] [Deny] |\n' "$status_icon" "$approval_type" "$agent_id" "$timeout_display"
  done
}

# Render recent completions as formatted table rows
# Input: JSON array of recent completions
# Output: Formatted table rows
render_recent_completions() {
  local completions_json="$1"
  local count
  count=$(printf '%s' "$completions_json" | jq 'length')

  if [ "$count" -eq 0 ]; then
    return
  fi

  # Render each completion as table row
  printf '%s' "$completions_json" | jq -r '.[] | "\(.issue // "?")|\(.timestamp // "")|\(.exit_code // 0)"' | while IFS='|' read -r issue timestamp exit_code; do
    # Determine result icon
    local result_icon="[OK]"
    if [ "$exit_code" != "0" ] && [ "$exit_code" != "null" ]; then
      result_icon="[XX]"
    fi

    # Format timestamp (extract time portion)
    local timestamp_display="--:--"
    if [ -n "$timestamp" ]; then
      timestamp_display=$(printf '%s' "$timestamp" | sed 's/T/ /' | cut -d'.' -f1 | cut -d' ' -f2 | cut -c1-5)
    fi

    # Duration placeholder (would need start/end tracking)
    local duration="--"

    printf '| %s | #%s | %s | %s |\n' "$timestamp_display" "$issue" "$result_icon" "$duration"
  done
}

# Main render function - generates dashboard output
render_dashboard() {
  # Run aggregate-status.sh to get current data
  local data
  if [ -f "$AGGREGATE_SCRIPT" ]; then
    # Source and capture output (more reliable on MINGW64)
    data=$( (cd "$(dirname "$AGGREGATE_SCRIPT")" && source "$(basename "$AGGREGATE_SCRIPT")" ) 2>/dev/null) || data='{}'
  else
    data='{}'
  fi

  # Extract values with jq (with defaults)
  local running blocked idle avg_trust warnings critical
  local completed total avg_time timestamp cache_status

  running=$(printf '%s' "$data" | jq -r '.agents.running // 0')
  blocked=$(printf '%s' "$data" | jq -r '.agents.blocked // 0')
  idle=$(printf '%s' "$data" | jq -r '.agents.idle // 0')

  avg_trust=$(printf '%s' "$data" | jq -r '.trust.avg_trust // 2')
  warnings=$(printf '%s' "$data" | jq -r '.trust.warnings // 0')
  critical=$(printf '%s' "$data" | jq -r '.trust.critical // 0')

  completed=$(printf '%s' "$data" | jq -r '.velocity.completions_24h // 0')
  total=$(printf '%s' "$data" | jq -r '.velocity.total_dispatches // 0')
  avg_time=$(printf '%s' "$data" | jq -r '.velocity.avg_duration_min // 0')

  timestamp=$(printf '%s' "$data" | jq -r '.timestamp // "N/A"' || echo "N/A")

  # Determine cache status
  local cached cache_age
  cached=$(printf '%s' "$data" | jq -r '.meta.cached // false')
  cache_age=$(printf '%s' "$data" | jq -r '.meta.cache_age_seconds // 0')
  if [ "$cached" = "true" ]; then
    local cache_min=$((cache_age / 60))
    cache_status="[CACHED ${cache_min}min]"
  else
    cache_status="[LIVE]"
  fi

  # Get approvals and completions JSON
  local approvals_json completions_json
  approvals_json=$(printf '%s' "$data" | jq -c '.approvals // []')
  completions_json=$(printf '%s' "$data" | jq -c '.recent_completions // []')

  local approvals_count completions_count
  approvals_count=$(printf '%s' "$approvals_json" | jq 'length')
  completions_count=$(printf '%s' "$completions_json" | jq 'length')

  # Calculate progress bar
  local percent=0
  if [ "$total" -gt 0 ] 2>/dev/null; then
    percent=$((completed * 100 / total))
  fi
  local progress_bar
  progress_bar=$(render_progress_bar "$percent")

  # Generate pending approvals section
  local approvals_section=""
  if [ "$approvals_count" -gt 0 ]; then
    approvals_section="| Status | Type | Agent | Timeout | Action |
|--------|------|-------|---------|--------|
$(render_pending_approvals "$approvals_json")"
  else
    approvals_section="[OK] No pending approvals - all agents operating normally."
  fi

  # Generate recent completions section
  local completions_section=""
  if [ "$completions_count" -gt 0 ]; then
    completions_section="| Time | Issue | Result | Duration |
|------|-------|--------|----------|
$(render_recent_completions "$completions_json")"
  else
    completions_section="[--] No recent completions in tracking window."
  fi

  # Output the dashboard (inline template for reliability)
  cat <<EOF
# Executive Dashboard

\`\`\`
+---------------------------------------------------------------+
|  EXECUTIVE DASHBOARD                           Refresh [R]    |
+---------------------------------------------------------------+
|                                                               |
|  AGENTS             PROJECT VELOCITY        TRUST HEALTH      |
|  ---------------    ------------------      ---------------   |
|  * $running Running        $progress_bar          Avg: Level $avg_trust   |
|  o $blocked Blocked        $completed/$total plans done      $warnings warning(s)    |
|  . $idle Idle           $avg_time min/task avg     $critical critical       |
|                                                               |
+---------------------------------------------------------------+
\`\`\`

## Needs Attention

$approvals_section

## Recent Completions

$completions_section

---

\`\`\`
+---------------------------------------------------------------+
|  $cache_status  Last updated: $timestamp               |
+---------------------------------------------------------------+
\`\`\`

## Status Icons Reference

| Icon | Meaning |
|------|---------|
| \`*\` | Running - Agent is actively executing a task |
| \`o\` | Blocked - Agent is waiting for approval |
| \`.\` | Idle - Agent is available for work |
| \`[OK]\` | Healthy - No issues |
| \`[!!]\` | Warning - Attention may be needed |
| \`[??]\` | Unknown - Status could not be determined |
| \`[XX]\` | Error - Immediate attention required |
| \`[--]\` | Empty - No data available |

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| \`R\` | Refresh dashboard data |
| \`A\` | Jump to Approvals section |
| \`C\` | Jump to Completions section |
| \`?\` | Show help |
EOF
}

# Execute
result=$(render_dashboard)

if [ -n "$OUTPUT_FILE" ]; then
  printf '%s\n' "$result" > "$OUTPUT_FILE"
  echo "Dashboard rendered to: $OUTPUT_FILE"
else
  printf '%s\n' "$result"
fi

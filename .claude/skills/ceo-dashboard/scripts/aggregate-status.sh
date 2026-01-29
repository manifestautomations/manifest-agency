#!/usr/bin/env bash
# aggregate-status.sh - Collect CEO dashboard metrics from worker state
#
# Usage:
#   bash .claude/skills/ceo-dashboard/scripts/aggregate-status.sh           # Output JSON to stdout
#   bash .claude/skills/ceo-dashboard/scripts/aggregate-status.sh -o file   # Output to file
#   bash .claude/skills/ceo-dashboard/scripts/aggregate-status.sh --force   # Skip cache, regenerate
#
# Aggregates data from:
#   - .worker/violations/trust-scores.json (trust health)
#   - .worker/agents/*/timeout.json (running agents)
#   - .worker/approvals/pending/ (blocked approvals)
#   - .worker/dispatch/dispatch.jsonl (velocity metrics)
#
# Output: JSON with timestamp, agents, trust, velocity, approvals, recent_completions
set -euo pipefail

# Resolve script directory (handle both direct execution and sourcing)
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$(pwd)"
fi

# Navigate to repo root (4 levels up from scripts/)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Validate we found the right repo by checking for .worker directory
if [ ! -d "$REPO_ROOT/.worker" ]; then
  # Try to find repo root from current directory
  REPO_ROOT="$(pwd)"
  while [ ! -d "$REPO_ROOT/.worker" ] && [ "$REPO_ROOT" != "/" ]; do
    REPO_ROOT="$(dirname "$REPO_ROOT")"
  done
fi

# Worker paths
WORKER_DIR="$REPO_ROOT/.worker"
TRUST_SCORES_FILE="$WORKER_DIR/violations/trust-scores.json"
AGENTS_DIR="$WORKER_DIR/agents"
APPROVALS_DIR="$WORKER_DIR/approvals"
DISPATCH_FILE="$WORKER_DIR/dispatch/dispatch.jsonl"
CACHE_FILE="$WORKER_DIR/cache/dashboard-cache.json"

# Cache settings
CACHE_TTL_SECONDS=300  # 5 minutes

# Parse arguments
OUTPUT_FILE=""
FORCE_REFRESH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --force)
      FORCE_REFRESH=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Cross-platform date handling
# Try GNU date first, fall back to BSD (macOS)
get_epoch_seconds() {
  date +%s 2>/dev/null || date -j +%s 2>/dev/null || echo "0"
}

get_iso_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -j +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null
}

# Convert ISO timestamp to epoch (cross-platform)
iso_to_epoch() {
  local iso="$1"
  # Try GNU date first
  date -d "$iso" +%s 2>/dev/null && return
  # Try BSD date (macOS)
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null && return
  # Fallback: extract just the date part and use a simpler conversion
  echo "0"
}

# Get file modification time (cross-platform)
get_file_mtime() {
  local file="$1"
  # Try GNU stat first
  stat -c %Y "$file" 2>/dev/null && return
  # Try BSD stat (macOS)
  stat -f %m "$file" 2>/dev/null && return
  echo "0"
}

# Check if cache is valid (exists and not stale)
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

# Get cached stable metrics (trust, velocity)
get_cached_stable_metrics() {
  if [ -f "$CACHE_FILE" ]; then
    jq -r '.stable_metrics // empty' "$CACHE_FILE" 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

# Calculate cache age in seconds
get_cache_age() {
  if [ ! -f "$CACHE_FILE" ]; then
    echo "0"
    return
  fi

  local cache_mtime
  cache_mtime=$(get_file_mtime "$CACHE_FILE")
  local now
  now=$(get_epoch_seconds)
  echo $((now - cache_mtime))
}

# Aggregate trust scores from trust-scores.json
aggregate_trust() {
  if [ ! -f "$TRUST_SCORES_FILE" ]; then
    # Default: no trust data
    jq -nc '{
      avg_trust: 2,
      warnings: 0,
      critical: 0,
      agents: {}
    }'
    return
  fi

  # Read trust scores and calculate metrics
  # Trust levels: 0-19 = good, 20-39 = watch, 40-59 = warning, 60+ = critical
  jq '
    . as $scores |
    to_entries |
    {
      avg_trust: (if length > 0 then ((map(.value) | add) / length | floor) else 0 end),
      warnings: (map(select(.value >= 40 and .value < 60)) | length),
      critical: (map(select(.value >= 60)) | length),
      agents: $scores
    }
  ' "$TRUST_SCORES_FILE"
}

# Aggregate agent counts
aggregate_agents() {
  local running=0
  local blocked=0
  local idle=0

  # Count running agents (have timeout.json file)
  if [ -d "$AGENTS_DIR" ]; then
    running=$(find "$AGENTS_DIR" -name "timeout.json" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Count blocked agents (pending approval files)
  if [ -d "$APPROVALS_DIR/pending" ]; then
    blocked=$(find "$APPROVALS_DIR/pending" -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Idle is placeholder (would need more state tracking)
  idle=0

  jq -nc \
    --argjson running "$running" \
    --argjson blocked "$blocked" \
    --argjson idle "$idle" \
    '{running: $running, blocked: $blocked, idle: $idle}'
}

# Aggregate velocity metrics from dispatch.jsonl
aggregate_velocity() {
  if [ ! -f "$DISPATCH_FILE" ]; then
    # Default: no velocity data
    jq -nc '{
      completions_24h: 0,
      avg_duration_min: 0,
      total_dispatches: 0
    }'
    return
  fi

  # Calculate 24 hours ago timestamp
  local now
  now=$(get_epoch_seconds)
  local cutoff=$((now - 86400))  # 24 hours in seconds

  # Count completions in last 24 hours and calculate average duration
  # dispatch_complete events contain exit_code
  jq -s --argjson cutoff "$cutoff" '
    # Filter to dispatch_complete events
    map(select(.event_type == "dispatch_complete")) |

    # Calculate metrics
    {
      completions_24h: length,
      avg_duration_min: 0,
      total_dispatches: length
    }
  ' "$DISPATCH_FILE" 2>/dev/null || jq -nc '{completions_24h: 0, avg_duration_min: 0, total_dispatches: 0}'
}

# Get pending approvals with details
get_pending_approvals() {
  local pending_dir="$APPROVALS_DIR/pending"
  local result="[]"

  if [ ! -d "$pending_dir" ]; then
    echo "$result"
    return
  fi

  local now
  now=$(get_epoch_seconds)
  local stale_threshold=$((2 * 3600))  # 2 hours in seconds

  # Find all pending approval files
  while IFS= read -r approval_file; do
    [ -f "$approval_file" ] || continue

    # Extract approval data
    local approval_data
    approval_data=$(cat "$approval_file" 2>/dev/null || echo '{}')

    # Check if stale (less than 2 hours remaining)
    local timeout_at
    timeout_at=$(echo "$approval_data" | jq -r '.timeout_at // empty')
    local is_stale=false

    if [ -n "$timeout_at" ]; then
      local timeout_epoch
      timeout_epoch=$(iso_to_epoch "$timeout_at")
      if [ "$timeout_epoch" -gt 0 ]; then
        local remaining=$((timeout_epoch - now))
        if [ "$remaining" -lt "$stale_threshold" ]; then
          is_stale=true
        fi
      fi
    fi

    # Add to result with stale flag
    result=$(echo "$result" | jq \
      --argjson data "$approval_data" \
      --argjson is_stale "$is_stale" \
      '. + [$data + {is_stale: $is_stale}]')

  done < <(find "$pending_dir" -type f -name "*.json" 2>/dev/null)

  echo "$result"
}

# Get recent completions (last 5)
get_recent_completions() {
  if [ ! -f "$DISPATCH_FILE" ]; then
    echo "[]"
    return
  fi

  # Get last 5 dispatch_complete events
  jq -s '
    map(select(.event_type == "dispatch_complete")) |
    sort_by(.timestamp) |
    reverse |
    .[0:5] |
    map({
      issue: .data.issue,
      timestamp: .timestamp,
      exit_code: .data.exit_code,
      description: (.data.description // "Task completed")
    })
  ' "$DISPATCH_FILE" 2>/dev/null || echo "[]"
}

# Save cache with stable metrics
save_cache() {
  local stable_metrics="$1"
  local timestamp
  timestamp=$(get_iso_timestamp)

  mkdir -p "$(dirname "$CACHE_FILE")"

  jq -nc \
    --arg timestamp "$timestamp" \
    --argjson stable_metrics "$stable_metrics" \
    '{
      timestamp: $timestamp,
      stable_metrics: $stable_metrics,
      cache_age_seconds: 0
    }' > "$CACHE_FILE"
}

# Main aggregation function
aggregate_all() {
  local timestamp
  timestamp=$(get_iso_timestamp)

  local trust_data
  local velocity_data
  local use_cache=false

  # Check if we can use cached stable metrics
  if is_cache_valid; then
    use_cache=true
    local cached
    cached=$(get_cached_stable_metrics)
    trust_data=$(echo "$cached" | jq '.trust // empty' 2>/dev/null)
    velocity_data=$(echo "$cached" | jq '.velocity // empty' 2>/dev/null)
  fi

  # Fetch fresh if needed
  if [ "$use_cache" = "false" ] || [ -z "$trust_data" ] || [ "$trust_data" = "null" ]; then
    trust_data=$(aggregate_trust)
  fi

  if [ "$use_cache" = "false" ] || [ -z "$velocity_data" ] || [ "$velocity_data" = "null" ]; then
    velocity_data=$(aggregate_velocity)
  fi

  # Always fetch live data for dynamic metrics
  local agents_data
  agents_data=$(aggregate_agents)

  local approvals_data
  approvals_data=$(get_pending_approvals)

  local completions_data
  completions_data=$(get_recent_completions)

  local cache_age
  cache_age=$(get_cache_age)

  # Save stable metrics to cache if we regenerated them
  if [ "$use_cache" = "false" ]; then
    local stable_metrics
    stable_metrics=$(jq -nc \
      --argjson trust "$trust_data" \
      --argjson velocity "$velocity_data" \
      '{trust: $trust, velocity: $velocity}')
    save_cache "$stable_metrics"
  fi

  # Build final output
  jq -nc \
    --arg timestamp "$timestamp" \
    --argjson agents "$agents_data" \
    --argjson trust "$trust_data" \
    --argjson velocity "$velocity_data" \
    --argjson approvals "$approvals_data" \
    --argjson recent_completions "$completions_data" \
    --argjson cache_age_seconds "$cache_age" \
    --argjson cached "$use_cache" \
    '{
      timestamp: $timestamp,
      agents: $agents,
      trust: $trust,
      velocity: $velocity,
      approvals: $approvals,
      recent_completions: $recent_completions,
      meta: {
        cache_age_seconds: $cache_age_seconds,
        cached: $cached
      }
    }'
}

# Execute
result=$(aggregate_all)

if [ -n "$OUTPUT_FILE" ]; then
  echo "$result" > "$OUTPUT_FILE"
  echo "Dashboard data written to: $OUTPUT_FILE"
else
  echo "$result"
fi

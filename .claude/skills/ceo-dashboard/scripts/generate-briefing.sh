#!/usr/bin/env bash
# generate-briefing.sh - Generate CEO daily briefing
#
# Usage:
#   bash .claude/skills/ceo-dashboard/scripts/generate-briefing.sh                  # Output to .worker/briefings/latest.md
#   bash .claude/skills/ceo-dashboard/scripts/generate-briefing.sh /path/out.md    # Custom output path
#   bash .claude/skills/ceo-dashboard/scripts/generate-briefing.sh --date 2026-01-28  # Generate for specific date
#
# Sections (in priority order):
#   1. Blockers - Pending approvals requiring action
#   2. Overnight - Completions and failures since last briefing
#   3. Health - Trust anomalies (only shown if warnings/critical exist)
#   4. Progress - Project completion snapshot
#   5. Outlook - Queued and pending work
#
# Output: Markdown briefing file (25-30 lines max, empty sections collapse)
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
  REPO_ROOT="$(pwd)"
  while [ ! -d "$REPO_ROOT/.worker" ] && [ "$REPO_ROOT" != "/" ]; do
    REPO_ROOT="$(dirname "$REPO_ROOT")"
  done
fi

# Worker paths
WORKER_DIR="$REPO_ROOT/.worker"
BRIEFINGS_DIR="$WORKER_DIR/briefings"
HISTORY_DIR="$BRIEFINGS_DIR/history"
TIMESTAMP_FILE="$BRIEFINGS_DIR/last-generated.timestamp"
STATE_FILE="$REPO_ROOT/.planning/STATE.md"

# Source dependency scripts
AGGREGATE_SCRIPT="$SCRIPT_DIR/aggregate-status.sh"
APPROVAL_SCRIPT="$SCRIPT_DIR/approval-workflow.sh"

# Parse arguments
OUTPUT="${1:-.worker/briefings/latest.md}"
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
  esac
done

# If OUTPUT starts with relative path, make it absolute from REPO_ROOT
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$REPO_ROOT/$OUTPUT"
fi

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Get current timestamp in ISO 8601 format
get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get current date in YYYY-MM-DD format
get_date() {
  date +%Y-%m-%d
}

# Get epoch seconds from ISO timestamp (cross-platform)
iso_to_epoch() {
  local iso="$1"
  # Try GNU date first
  date -d "$iso" +%s 2>/dev/null && return
  # Try BSD date (macOS)
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null && return
  echo "0"
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
  cp "$briefing_file" "$HISTORY_DIR/${archive_date}.md" 2>/dev/null || true
}

# Clean up old briefings (keep last 30 days)
cleanup_old_briefings() {
  [ -d "$HISTORY_DIR" ] || return 0
  find "$HISTORY_DIR" -name "*.md" -mtime +30 -delete 2>/dev/null || true
}

# Format time remaining for human display
format_time_remaining() {
  local seconds="$1"

  if [ "$seconds" = "infinite" ]; then
    echo "no timeout"
  elif [ "$seconds" -lt 0 ]; then
    echo "EXPIRED"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds / 60))m"
  elif [ "$seconds" -lt 86400 ]; then
    echo "$((seconds / 3600))h $((seconds % 3600 / 60))m"
  else
    echo "$((seconds / 86400))d"
  fi
}

# -----------------------------------------------------------------------------
# Section Generators
# -----------------------------------------------------------------------------

# Section 1: Blockers (Pending Approvals)
# Returns: Markdown section or empty string if no blockers
generate_blockers_section() {
  # Source approval workflow if available
  if [ -f "$APPROVAL_SCRIPT" ]; then
    # shellcheck source=/dev/null
    source "$APPROVAL_SCRIPT" 2>/dev/null || true
  fi

  local pending_dir="$WORKER_DIR/approvals/pending"
  local blockers=""
  local count=0

  # Check for pending approvals
  if [ -d "$pending_dir" ]; then
    while IFS= read -r approval_file; do
      [ -f "$approval_file" ] || continue

      local data
      data=$(cat "$approval_file" 2>/dev/null || echo '{}')

      local approval_id approval_type agent_id timeout_at context
      approval_id=$(echo "$data" | jq -r '.approval_id // "unknown"')
      approval_type=$(echo "$data" | jq -r '.type // "unknown"')
      agent_id=$(echo "$data" | jq -r '.agent_id // "unknown"')
      timeout_at=$(echo "$data" | jq -r '.timeout_at // ""')
      context=$(echo "$data" | jq -r '.context // {} | if type == "object" then (.reason // .description // "Approval required") else . end')

      # Calculate time remaining
      local time_remaining="infinite"
      if [ -n "$timeout_at" ] && [ "$timeout_at" != "9999-12-31T23:59:59Z" ]; then
        local now_epoch timeout_epoch
        now_epoch=$(get_epoch)
        timeout_epoch=$(iso_to_epoch "$timeout_at")
        if [ "$timeout_epoch" -gt 0 ]; then
          time_remaining=$((timeout_epoch - now_epoch))
        fi
      fi

      local time_str
      time_str=$(format_time_remaining "$time_remaining")

      blockers="${blockers}- **${approval_type}** for \`${agent_id}\`
  - ${context}
  - Timeout: ${time_str} | [Approve](cmd:approve ${approval_id}) | [Deny](cmd:deny ${approval_id})
"
      count=$((count + 1))
    done < <(find "$pending_dir" -type f -name "*.json" 2>/dev/null)
  fi

  # Return section only if there are blockers
  if [ "$count" -gt 0 ]; then
    echo "## Blockers

${blockers}"
  fi
}

# Section 2: Overnight Summary
# Returns: Markdown section or empty string if no overnight activity
generate_overnight_section() {
  local last_briefing
  last_briefing=$(get_last_briefing_time)
  local last_epoch
  last_epoch=$(iso_to_epoch "$last_briefing")

  local completions=0
  local failures=0
  local milestones=""

  # Check dispatch log for completions and failures since last briefing
  local dispatch_file="$WORKER_DIR/dispatch/dispatch.jsonl"
  if [ -f "$dispatch_file" ]; then
    # Count completions (exit_code 0) since last briefing
    completions=$(jq -s --argjson cutoff "$last_epoch" '
      map(select(
        .event_type == "dispatch_complete" and
        (.data.exit_code // 1) == 0
      )) | length
    ' "$dispatch_file" 2>/dev/null || echo 0)

    # Count failures (exit_code != 0) since last briefing
    failures=$(jq -s --argjson cutoff "$last_epoch" '
      map(select(
        .event_type == "dispatch_complete" and
        (.data.exit_code // 1) != 0
      )) | length
    ' "$dispatch_file" 2>/dev/null || echo 0)
  fi

  # Check for milestones (phase completions) by looking at SUMMARY files
  local phase_summaries
  phase_summaries=$(find "$REPO_ROOT/.planning/phases" -name "*-SUMMARY.md" -newer "$TIMESTAMP_FILE" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$phase_summaries" -gt 0 ]; then
    milestones="- Milestone: ${phase_summaries} plan(s) completed"
  fi

  # Return section only if there's overnight activity
  if [ "$completions" -gt 0 ] || [ "$failures" -gt 0 ] || [ -n "$milestones" ]; then
    local section="## Overnight Summary

- Completions: ${completions}
- Failures: ${failures}"

    if [ -n "$milestones" ]; then
      section="${section}
${milestones}"
    fi

    printf '%s\n' "$section"
  fi
}

# Section 3: Health Indicators
# Returns: Markdown section only if warnings > 0 or critical > 0
generate_health_section() {
  local trust_file="$WORKER_DIR/violations/trust-scores.json"
  local avg_trust=2
  local warnings=0
  local critical=0

  if [ -f "$trust_file" ]; then
    # Calculate trust metrics from scores
    # Trust levels: 0-19 = good, 20-39 = watch, 40-59 = warning, 60+ = critical
    local metrics
    metrics=$(jq '
      to_entries |
      {
        avg_trust: (if length > 0 then ((map(.value) | add) / length | floor) else 2 end),
        warnings: (map(select(.value >= 40 and .value < 60)) | length),
        critical: (map(select(.value >= 60)) | length)
      }
    ' "$trust_file" 2>/dev/null || echo '{"avg_trust":2,"warnings":0,"critical":0}')

    avg_trust=$(echo "$metrics" | jq -r '.avg_trust // 2')
    warnings=$(echo "$metrics" | jq -r '.warnings // 0')
    critical=$(echo "$metrics" | jq -r '.critical // 0')
  fi

  # Only show section if there are warnings or critical issues
  if [ "$warnings" -gt 0 ] || [ "$critical" -gt 0 ]; then
    local section="## Health Indicators

- Average Trust: Level ${avg_trust}"

    if [ "$warnings" -gt 0 ]; then
      section="${section}
- Warning: ${warnings} agent(s) approaching demotion"
    fi

    if [ "$critical" -gt 0 ]; then
      section="${section}
- CRITICAL: ${critical} agent(s) require immediate attention"
    fi

    printf '%s\n' "$section"
  fi
}

# Section 4: Progress Snapshot
# Returns: Markdown section (always shown, provides project context)
generate_progress_section() {
  local percent=0
  local avg_time="N/A"
  local current_phase="Unknown"
  local velocity_data=""

  # Extract progress from STATE.md
  if [ -f "$STATE_FILE" ]; then
    # Parse overall progress percentage
    local overall_line
    overall_line=$(grep "^Overall:" "$STATE_FILE" 2>/dev/null || echo "")
    if [ -n "$overall_line" ]; then
      # Extract percentage: Overall:  [=========>] 94% (29 of 31 plans)
      percent=$(echo "$overall_line" | grep -oE '[0-9]+%' | head -1 | tr -d '%' || echo "0")
    fi

    # Extract current phase
    local phase_line
    phase_line=$(grep "^Phase:" "$STATE_FILE" 2>/dev/null || echo "")
    if [ -n "$phase_line" ]; then
      # Extract phase name: Phase: 7 of 7 (CEO Interface) - IN PROGRESS
      current_phase=$(echo "$phase_line" | sed -E 's/.*\(([^)]+)\).*/\1/' || echo "Unknown")
    fi
  fi

  # Get velocity from aggregate-status if available
  if [ -f "$AGGREGATE_SCRIPT" ]; then
    velocity_data=$(bash "$AGGREGATE_SCRIPT" 2>/dev/null || echo '{}')
    if [ -n "$velocity_data" ]; then
      local avg_duration
      avg_duration=$(echo "$velocity_data" | jq -r '.velocity.avg_duration_min // 0')
      if [ "$avg_duration" != "0" ] && [ "$avg_duration" != "null" ]; then
        avg_time="${avg_duration} min/task"
      fi
    fi
  fi

  # Also check STATE.md for velocity
  if [ "$avg_time" = "N/A" ] && [ -f "$STATE_FILE" ]; then
    local avg_line
    avg_line=$(grep "Average duration:" "$STATE_FILE" 2>/dev/null || echo "")
    if [ -n "$avg_line" ]; then
      avg_time=$(echo "$avg_line" | sed -E 's/.*: ([0-9.]+).*/\1/' || echo "N/A")
      avg_time="${avg_time} min"
    fi
  fi

  echo "## Progress Snapshot

- Project: ${percent}% complete
- Velocity: ${avg_time}
- Phase: ${current_phase}
"
}

# Section 5: Today's Outlook
# Returns: Markdown section or empty string if nothing queued
generate_outlook_section() {
  local queued=0
  local pending=0

  # Check dispatch queue for queued work
  local queue_file="$WORKER_DIR/dispatch/queue.jsonl"
  if [ -f "$queue_file" ]; then
    queued=$(wc -l < "$queue_file" | tr -d ' ')
  fi

  # Check for pending (blocked) issues via labels
  local agents_dir="$WORKER_DIR/agents"
  if [ -d "$agents_dir" ]; then
    pending=$(find "$agents_dir" -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Only show section if there's something queued or pending
  if [ "$queued" -gt 0 ] || [ "$pending" -gt 0 ]; then
    echo "## Today's Outlook

- Queued: ${queued} items
- Pending: ${pending} items
"
  fi
}

# -----------------------------------------------------------------------------
# Main Function
# -----------------------------------------------------------------------------

generate_briefing() {
  local output_file="$1"
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
  local briefing="# Daily Briefing - ${briefing_date}
"

  # Generate sections (in priority order)
  # Each section is separated by a blank line for readability
  local blockers_section
  blockers_section=$(generate_blockers_section)
  if [ -n "$blockers_section" ]; then
    briefing="${briefing}
${blockers_section}
"
  fi

  local overnight_section
  overnight_section=$(generate_overnight_section)
  if [ -n "$overnight_section" ]; then
    briefing="${briefing}
${overnight_section}
"
  fi

  local health_section
  health_section=$(generate_health_section)
  if [ -n "$health_section" ]; then
    briefing="${briefing}
${health_section}
"
  fi

  # Progress section always shown
  local progress_section
  progress_section=$(generate_progress_section)
  briefing="${briefing}
${progress_section}
"

  local outlook_section
  outlook_section=$(generate_outlook_section)
  if [ -n "$outlook_section" ]; then
    briefing="${briefing}
${outlook_section}"
  fi

  # Add footer with timestamp
  local timestamp
  timestamp=$(get_timestamp)
  briefing="${briefing}
---
_Generated: ${timestamp}_"

  # Write briefing to file
  echo "$briefing" > "$output_file"

  # Update timestamp and cleanup
  update_briefing_timestamp
  cleanup_old_briefings

  echo "[briefing] Generated: $output_file"
  echo "[briefing] Lines: $(wc -l < "$output_file" | tr -d ' ')"
}

# Execute
generate_briefing "$OUTPUT"

# -----------------------------------------------------------------------------
# Inbox Integration
# -----------------------------------------------------------------------------

# Deliver briefing notification to Inbox conversation
INBOX_INTEGRATION_SCRIPT="$SCRIPT_DIR/../inbox-integration.sh"
if [ -f "$INBOX_INTEGRATION_SCRIPT" ]; then
  # shellcheck source=/dev/null
  source "$INBOX_INTEGRATION_SCRIPT"

  # Check for duplicate delivery (prevents double-delivery on manual runs)
  local briefing_id
  briefing_id="briefing-$(date +%Y-%m-%d)"
  local is_duplicate
  is_duplicate=$(check_duplicate_delivery "$briefing_id")

  if [ "$is_duplicate" = "false" ]; then
    # Get notification tier for briefings
    TIER=$(get_notification_tier "briefing")

    # Format and deliver briefing notification
    format_briefing_notification "$OUTPUT" | deliver_to_inbox "$TIER"
    echo "[briefing] Delivered to Inbox (tier: $TIER)"
  else
    echo "[briefing] Skipped Inbox delivery (already delivered today)"
  fi
fi

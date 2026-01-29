#!/usr/bin/env bash
# inbox-integration.sh - Wire skills to Antigravity Inbox conversation
#
# Usage:
#   source .claude/skills/ceo-dashboard/inbox-integration.sh
#
#   # Get notification tier for event type
#   TIER=$(get_notification_tier "critical_violation")
#
#   # Format and deliver messages
#   format_briefing_notification "/path/to/briefing.md" | deliver_to_inbox "briefing"
#   format_approval_request "id" "type" "agent" "context" | deliver_to_inbox "critical_violation"
#   format_blocked_status '["agent1","agent2"]'
#
# Notification Tiers:
#   immediate - Critical violations, system down (push notification)
#   delayed   - Stale approvals, blocked agents (batched every 2h)
#   silent    - Briefings, completions (appear in Inbox without push)
#
# CEO Modes:
#   dnd     - Only immediate notifications delivered
#   normal  - Immediate + delayed notifications
#   verbose - All notifications delivered

# Guard against re-sourcing (only when sourced, not when run directly)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  [[ -n "${_INBOX_INTEGRATION_SOURCED:-}" ]] && return 0
  _INBOX_INTEGRATION_SOURCED=1
fi

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [ ! -d "$REPO_ROOT/.worker" ]; then
  REPO_ROOT="$(pwd)"
  while [ ! -d "$REPO_ROOT/.worker" ] && [ "$REPO_ROOT" != "/" ]; do
    REPO_ROOT="$(dirname "$REPO_ROOT")"
  done
fi

CONFIG_FILE="$REPO_ROOT/.worker/config.json"
INBOX_DIR="$REPO_ROOT/.worker/inbox"

# -----------------------------------------------------------------------------
# Configuration Functions
# -----------------------------------------------------------------------------

# Get notification tier for event type
# Input: event_type (critical_violation, blocked_agent, stale_approval, briefing, completion, etc.)
# Output: tier (immediate, delayed, silent)
get_notification_tier() {
  local event_type="$1"

  if [ ! -f "$CONFIG_FILE" ]; then
    # Default tiers if config not found
    case "$event_type" in
      critical_violation|system_down) echo "immediate" ;;
      blocked_agent|stale_approval) echo "delayed" ;;
      *) echo "silent" ;;
    esac
    return 0
  fi

  local tier
  tier=$(jq -r --arg type "$event_type" '.ceo_interface.notification_tiers[$type] // "silent"' "$CONFIG_FILE" 2>/dev/null)

  if [ -z "$tier" ] || [ "$tier" = "null" ]; then
    # Fallback defaults
    case "$event_type" in
      critical_violation|system_down) tier="immediate" ;;
      blocked_agent|stale_approval) tier="delayed" ;;
      *) tier="silent" ;;
    esac
  fi

  echo "$tier"
}

# Check if message should be delivered now based on tier and CEO mode
# Input: tier, ceo_mode (dnd, normal, verbose)
# Output: true/false
should_deliver_now() {
  local tier="$1"
  local ceo_mode="${2:-normal}"

  # Get CEO mode from config if not provided
  if [ "$ceo_mode" = "normal" ] && [ -f "$CONFIG_FILE" ]; then
    ceo_mode=$(jq -r '.ceo_interface.ceo_mode // "normal"' "$CONFIG_FILE" 2>/dev/null)
    [ -z "$ceo_mode" ] || [ "$ceo_mode" = "null" ] && ceo_mode="normal"
  fi

  case "$ceo_mode" in
    dnd)
      # DND mode: only immediate notifications
      [ "$tier" = "immediate" ] && echo "true" || echo "false"
      ;;
    normal)
      # Normal mode: immediate + delayed
      [ "$tier" = "immediate" ] || [ "$tier" = "delayed" ] && echo "true" || echo "false"
      ;;
    verbose)
      # Verbose mode: all notifications
      echo "true"
      ;;
    *)
      # Default to normal behavior
      [ "$tier" = "immediate" ] || [ "$tier" = "delayed" ] && echo "true" || echo "false"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Message Formatting Functions
# -----------------------------------------------------------------------------

# Format a generic Inbox message
# Input: type, content, actions (optional JSON array)
# Output: Inbox-formatted markdown
format_inbox_message() {
  local msg_type="$1"
  local content="$2"
  local actions="${3:-[]}"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Type badge mapping
  local badge
  case "$msg_type" in
    critical_violation) badge="[CRITICAL]" ;;
    blocked_agent) badge="[BLOCKED]" ;;
    stale_approval) badge="[STALE]" ;;
    briefing) badge="[BRIEFING]" ;;
    completion) badge="[COMPLETE]" ;;
    trust_promotion) badge="[TRUST]" ;;
    scope_access) badge="[ACCESS]" ;;
    *) badge="[INFO]" ;;
  esac

  # Build message
  local message="---
type: $msg_type
timestamp: $timestamp
---

$badge

$content"

  # Add action buttons if provided
  if [ "$actions" != "[]" ] && [ -n "$actions" ]; then
    message="$message

---
**Actions:**
"
    # Parse and add each action button
    local action_count
    action_count=$(echo "$actions" | jq 'length' 2>/dev/null || echo 0)

    for ((i=0; i<action_count; i++)); do
      local label url
      label=$(echo "$actions" | jq -r ".[$i].label // \"Action\"")
      url=$(echo "$actions" | jq -r ".[$i].url // \"#\"")
      message="$message
[$label]($url)"
    done
  fi

  echo "$message"
}

# Format an approval request for Inbox
# Input: approval_id, type, agent, context
# Output: Formatted approval request message
format_approval_request() {
  local approval_id="$1"
  local approval_type="$2"
  local agent_id="$3"
  local context="$4"

  # Type badge
  local type_badge
  case "$approval_type" in
    trust_promotion) type_badge="Trust Promotion" ;;
    critical_violation) type_badge="CRITICAL VIOLATION" ;;
    scope_access) type_badge="Scope Access" ;;
    cross_workspace) type_badge="Cross-Workspace" ;;
    *) type_badge="$approval_type" ;;
  esac

  # Get timeout from config or default
  local timeout_info="24h"
  if [ "$approval_type" = "critical_violation" ]; then
    timeout_info="no timeout"
  fi

  # Build content
  local content="## Approval Required

**Type:** $type_badge
**Agent:** \`$agent_id\`
**Request ID:** \`$approval_id\`

### Context
$context

**Timeout:** $timeout_info"

  # Build actions
  local actions
  actions=$(jq -nc \
    --arg approve_url "action://approve?id=$approval_id" \
    --arg deny_url "action://deny?id=$approval_id" \
    '[
      {"label": "Approve", "url": $approve_url},
      {"label": "Deny", "url": $deny_url}
    ]')

  format_inbox_message "$approval_type" "$content" "$actions"
}

# Format a briefing notification for Inbox
# Input: briefing_path
# Output: Formatted briefing notification
format_briefing_notification() {
  local briefing_path="$1"

  # Default stats if file not readable
  local completions=0
  local blockers=0
  local date_str
  date_str=$(date +%Y-%m-%d)

  # Extract summary stats from briefing if available
  if [ -f "$briefing_path" ]; then
    # Count blockers (pending approvals)
    blockers=$(grep -c "^\- \*\*" "$briefing_path" 2>/dev/null | head -1 || echo 0)

    # Extract completions from overnight section
    local completions_line
    completions_line=$(grep "Completions:" "$briefing_path" 2>/dev/null || echo "")
    if [ -n "$completions_line" ]; then
      completions=$(echo "$completions_line" | grep -oE '[0-9]+' | head -1 || echo 0)
    fi

    # Extract date from briefing header
    local header_date
    header_date=$(grep "^# Daily Briefing" "$briefing_path" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")
    [ -n "$header_date" ] && date_str="$header_date"
  fi

  local content="## Daily Briefing - $date_str

**Summary:**
- Completions: $completions
- Blockers: $blockers"

  if [ "$blockers" -gt 0 ]; then
    content="$content

Items require your attention."
  else
    content="$content

All clear - no blockers today."
  fi

  # Build actions
  local actions
  actions=$(jq -nc \
    --arg view_url "action://briefing?view=full" \
    '[{"label": "View Full Briefing", "url": $view_url}]')

  format_inbox_message "briefing" "$content" "$actions"
}

# Format blocked agent status for Inbox badge
# Input: blocked_agents (JSON array or space-separated list)
# Output: Compact badge format
format_blocked_status() {
  local blocked_input="$1"
  local count=0

  # Try to parse as JSON array
  if echo "$blocked_input" | jq empty 2>/dev/null; then
    count=$(echo "$blocked_input" | jq 'length' 2>/dev/null || echo 0)
  else
    # Treat as space-separated list
    count=$(echo "$blocked_input" | wc -w | tr -d ' ')
  fi

  # Urgency color/marker based on count
  local urgency_marker=""
  if [ "$count" -ge 5 ]; then
    urgency_marker="[!!] "
  elif [ "$count" -ge 2 ]; then
    urgency_marker="[!] "
  fi

  if [ "$count" -eq 0 ]; then
    echo "No blocked agents"
  elif [ "$count" -eq 1 ]; then
    echo "${urgency_marker}1 agent blocked"
  else
    echo "${urgency_marker}${count} agents blocked"
  fi
}

# -----------------------------------------------------------------------------
# Delivery Functions
# -----------------------------------------------------------------------------

# Deliver message to Inbox
# Input: message (stdin), tier
# Creates timestamped file in .worker/inbox/
deliver_to_inbox() {
  local tier="${1:-silent}"
  local message
  message=$(cat)

  # Ensure inbox directory exists
  mkdir -p "$INBOX_DIR"

  # Generate filename: timestamp-type.md
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

  # Check if we should deliver based on CEO mode
  local should_deliver
  should_deliver=$(should_deliver_now "$tier")

  if [ "$should_deliver" = "true" ]; then
    # Write message with delivery metadata
    echo "${delivery_meta}${message}" > "$filepath"
    echo "[inbox] Delivered: $filename (tier: $tier)"
  else
    # Queue for later delivery (store with .queued extension)
    echo "${delivery_meta}${message}" > "${filepath}.queued"
    echo "[inbox] Queued: $filename (tier: $tier, awaiting delivery)"
  fi

  return 0
}

# Check for duplicate delivery (prevents double-delivery of same content)
# Input: content_hash or identifier
# Output: true if duplicate, false if new
check_duplicate_delivery() {
  local identifier="$1"
  local dedup_file="$INBOX_DIR/.delivered-today"
  local today
  today=$(date +%Y-%m-%d)

  # Create dedup file if needed
  if [ ! -f "$dedup_file" ]; then
    echo "$today" > "$dedup_file"
  fi

  # Check if date changed (new day = reset dedup)
  local file_date
  file_date=$(head -1 "$dedup_file" 2>/dev/null || echo "")
  if [ "$file_date" != "$today" ]; then
    echo "$today" > "$dedup_file"
  fi

  # Check for duplicate
  if grep -qF "$identifier" "$dedup_file" 2>/dev/null; then
    echo "true"
    return 0
  fi

  # Record this delivery
  echo "$identifier" >> "$dedup_file"
  echo "false"
  return 0
}

# -----------------------------------------------------------------------------
# CLI Interface
# -----------------------------------------------------------------------------

_show_inbox_help() {
  cat <<'HELP'
inbox-integration.sh - Inbox message formatting and delivery

USAGE:
  source inbox-integration.sh   # Source for function access
  inbox-integration.sh <command> [args]

COMMANDS:
  tier <event_type>
      Get notification tier for event type

  deliver <tier>
      Deliver message from stdin to Inbox

  format-approval <id> <type> <agent> <context>
      Format an approval request

  format-briefing <path>
      Format a briefing notification

  format-blocked <agents_json>
      Format blocked agent badge

  should-deliver <tier> [ceo_mode]
      Check if message should be delivered now

  help
      Show this help

EXAMPLES:
  # Get tier for an event
  ./inbox-integration.sh tier critical_violation

  # Format and deliver approval request
  ./inbox-integration.sh format-approval "id-123" "trust_promotion" "agent-1" "Requesting level 3" | \
    ./inbox-integration.sh deliver delayed

  # Check blocked agent status
  ./inbox-integration.sh format-blocked '["agent-1","agent-2"]'
HELP
}

# CLI entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    tier)
      get_notification_tier "$2"
      ;;
    deliver)
      deliver_to_inbox "${2:-silent}"
      ;;
    format-approval)
      format_approval_request "$2" "$3" "$4" "$5"
      ;;
    format-briefing)
      format_briefing_notification "$2"
      ;;
    format-blocked)
      format_blocked_status "$2"
      ;;
    should-deliver)
      should_deliver_now "$2" "${3:-normal}"
      ;;
    help|--help|-h)
      _show_inbox_help
      ;;
    *)
      echo "Usage: $0 {tier|deliver|format-approval|format-briefing|format-blocked|should-deliver|help}" >&2
      echo "Run '$0 help' for detailed usage information." >&2
      exit 1
      ;;
  esac
fi

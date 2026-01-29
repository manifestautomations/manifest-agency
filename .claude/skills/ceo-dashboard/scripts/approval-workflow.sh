#!/usr/bin/env bash
# approval-workflow.sh - File-based approval state management
# Source: Adapted from lock.sh timeout detection pattern and audit.sh logging
#
# Usage:
#   source .claude/skills/ceo-dashboard/scripts/approval-workflow.sh
#   create_approval_request "trust_promotion" "agent-1" '{"reason":"level 2 to 3"}'
#   approve_request "approval-12345" "Promoted based on performance"
#   deny_request "approval-12345" "Insufficient track record"
#   list_pending_approvals
#
# Approval Types:
#   trust_promotion    - Agent trust level changes
#   critical_violation - Security/safety violations (NEVER auto-deny)
#   scope_access       - Access to new directories/resources
#   cross_workspace    - Operations spanning multiple workspaces
#
# State Model:
#   .worker/approvals/pending/{approval_id}.json   - Awaiting decision
#   .worker/approvals/approved/{approval_id}.json  - Approved requests
#   .worker/approvals/denied/{approval_id}.json    - Denied requests
#   .worker/approvals/registry.jsonl               - Append-only audit trail

# Guard against re-sourcing (only when sourced, not when run directly)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Being sourced - apply re-source guard
  [[ -n "${_APPROVAL_WORKFLOW_SOURCED:-}" ]] && return 0
  _APPROVAL_WORKFLOW_SOURCED=1
fi

# Directory paths
APPROVALS_DIR=".worker/approvals"
PENDING_DIR="$APPROVALS_DIR/pending"
APPROVED_DIR="$APPROVALS_DIR/approved"
DENIED_DIR="$APPROVALS_DIR/denied"
REGISTRY_FILE="$APPROVALS_DIR/registry.jsonl"

# Timeout configuration
DEFAULT_TIMEOUT_HOURS=24
CRITICAL_TIMEOUT="9999-12-31T23:59:59Z"  # Never expires
STALE_THRESHOLD_SECONDS=7200  # 2 hours = stale warning

# Valid approval types
VALID_TYPES=("trust_promotion" "critical_violation" "scope_access" "cross_workspace")

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Ensure approval directories exist
_ensure_approval_dirs() {
  mkdir -p "$PENDING_DIR" "$APPROVED_DIR" "$DENIED_DIR"
}

# Get current timestamp in ISO 8601 format
_get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Convert ISO 8601 timestamp to epoch seconds (cross-platform)
_timestamp_to_epoch() {
  local ts="$1"
  # Try GNU date first, fall back to BSD/macOS
  date -d "$ts" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo 0
}

# Get current epoch seconds
_get_epoch() {
  date +%s
}

# Calculate timeout timestamp (24 hours from now, or infinite for critical)
_calculate_timeout() {
  local approval_type="$1"

  if [[ "$approval_type" == "critical_violation" ]]; then
    echo "$CRITICAL_TIMEOUT"
  else
    # Add 24 hours to current time
    local now_epoch
    now_epoch=$(_get_epoch)
    local timeout_epoch=$((now_epoch + DEFAULT_TIMEOUT_HOURS * 3600))
    date -u -d "@$timeout_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
      date -u -r "$timeout_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
      echo "$(date -u +%Y-%m-%d)T23:59:59Z"
  fi
}

# Validate approval type
_validate_type() {
  local type="$1"
  for valid in "${VALID_TYPES[@]}"; do
    [[ "$type" == "$valid" ]] && return 0
  done
  return 1
}

# Append entry to registry (append-only audit log)
_append_to_registry() {
  local entry="$1"
  echo "$entry" >> "$REGISTRY_FILE"
}

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

# Create a new approval request
# Arguments: approval_type agent_id context_json
# Returns: approval_id on stdout, 0 on success, 1 on failure
create_approval_request() {
  local approval_type="$1"
  local agent_id="$2"
  local context_json="${3:-"{}"}"

  # Validate inputs
  if [[ -z "$approval_type" || -z "$agent_id" ]]; then
    echo "[error] Usage: create_approval_request <type> <agent_id> [context_json]" >&2
    return 1
  fi

  if ! _validate_type "$approval_type"; then
    echo "[error] Invalid approval type: $approval_type" >&2
    echo "[error] Valid types: ${VALID_TYPES[*]}" >&2
    return 1
  fi

  # Validate context is valid JSON
  if ! echo "$context_json" | jq empty 2>/dev/null; then
    echo "[error] Invalid context JSON: $context_json" >&2
    return 1
  fi

  _ensure_approval_dirs

  # Generate unique approval ID using timestamp + nanoseconds
  local approval_id="approval-$(date +%s%N)"

  # Calculate timestamps
  local created_at
  created_at=$(_get_timestamp)
  local timeout_at
  timeout_at=$(_calculate_timeout "$approval_type")

  # Build approval request JSON
  local request_json
  request_json=$(jq -nc \
    --arg approval_id "$approval_id" \
    --arg approval_type "$approval_type" \
    --arg agent_id "$agent_id" \
    --argjson context "$context_json" \
    --arg created_at "$created_at" \
    --arg timeout_at "$timeout_at" \
    --arg status "pending" \
    '{
      approval_id: $approval_id,
      type: $approval_type,
      agent_id: $agent_id,
      context: $context,
      created_at: $created_at,
      timeout_at: $timeout_at,
      status: $status
    }')

  # Write to pending directory
  local pending_file="$PENDING_DIR/${approval_id}.json"
  echo "$request_json" > "$pending_file"

  # Append to registry for audit trail
  local registry_entry
  registry_entry=$(jq -nc \
    --arg event "approval_created" \
    --arg approval_id "$approval_id" \
    --arg approval_type "$approval_type" \
    --arg agent_id "$agent_id" \
    --arg created_at "$created_at" \
    --arg timeout_at "$timeout_at" \
    '{
      event: $event,
      approval_id: $approval_id,
      type: $approval_type,
      agent_id: $agent_id,
      created_at: $created_at,
      timeout_at: $timeout_at
    }')
  _append_to_registry "$registry_entry"

  # Deliver approval request to Inbox conversation
  local inbox_script
  inbox_script="$(dirname "${BASH_SOURCE[0]}")/../inbox-integration.sh"
  if [[ -f "$inbox_script" ]]; then
    # shellcheck source=/dev/null
    source "$inbox_script" 2>/dev/null || true

    # Get notification tier for this approval type
    local tier
    tier=$(get_notification_tier "$approval_type" 2>/dev/null || echo "delayed")

    # Format context for display
    local context_display
    context_display=$(echo "$context_json" | jq -r 'if type == "object" then (.reason // .description // "Approval required") else . end' 2>/dev/null || echo "Approval required")

    # Format and deliver to Inbox
    format_approval_request "$approval_id" "$approval_type" "$agent_id" "$context_display" 2>/dev/null | deliver_to_inbox "$tier" 2>/dev/null || true
    echo "[approval] Delivered to Inbox (tier: $tier)" >&2
  fi

  # Return approval ID
  echo "$approval_id"
  return 0
}

# Approve an approval request
# Arguments: approval_id [justification]
# Returns: 0 on success, 1 on failure
approve_request() {
  local approval_id="$1"
  local justification="${2:-}"

  if [[ -z "$approval_id" ]]; then
    echo "[error] Usage: approve_request <approval_id> [justification]" >&2
    return 1
  fi

  local pending_file="$PENDING_DIR/${approval_id}.json"

  # Verify pending file exists
  if [[ ! -f "$pending_file" ]]; then
    echo "[error] Approval request not found: $approval_id" >&2
    echo "[error] File: $pending_file" >&2
    return 1
  fi

  # Read current request
  local request
  request=$(cat "$pending_file")

  # Add decision metadata
  local decided_at
  decided_at=$(_get_timestamp)

  local updated_request
  updated_request=$(echo "$request" | jq \
    --arg status "approved" \
    --arg decided_at "$decided_at" \
    --arg justification "$justification" \
    '. + {
      status: $status,
      decided_at: $decided_at,
      decision: {
        outcome: "approved",
        justification: (if $justification == "" then null else $justification end),
        decided_at: $decided_at
      }
    }')

  # Write to approved directory
  local approved_file="$APPROVED_DIR/${approval_id}.json"
  echo "$updated_request" > "$approved_file"

  # Remove from pending (atomic: write first, then remove)
  rm -f "$pending_file"

  # Append to registry
  local agent_id
  agent_id=$(echo "$request" | jq -r '.agent_id')
  local approval_type
  approval_type=$(echo "$request" | jq -r '.type')

  local registry_entry
  registry_entry=$(jq -nc \
    --arg event "approval_approved" \
    --arg approval_id "$approval_id" \
    --arg approval_type "$approval_type" \
    --arg agent_id "$agent_id" \
    --arg decided_at "$decided_at" \
    --arg justification "$justification" \
    '{
      event: $event,
      approval_id: $approval_id,
      type: $approval_type,
      agent_id: $agent_id,
      decided_at: $decided_at,
      justification: (if $justification == "" then null else $justification end)
    }')
  _append_to_registry "$registry_entry"

  echo "[approval] Approved: $approval_id"
  return 0
}

# Deny an approval request
# Arguments: approval_id [reason]
# Returns: 0 on success, 1 on failure
deny_request() {
  local approval_id="$1"
  local reason="${2:-}"

  if [[ -z "$approval_id" ]]; then
    echo "[error] Usage: deny_request <approval_id> [reason]" >&2
    return 1
  fi

  local pending_file="$PENDING_DIR/${approval_id}.json"

  # Verify pending file exists
  if [[ ! -f "$pending_file" ]]; then
    echo "[error] Approval request not found: $approval_id" >&2
    echo "[error] File: $pending_file" >&2
    return 1
  fi

  # Read current request
  local request
  request=$(cat "$pending_file")

  # Add decision metadata
  local decided_at
  decided_at=$(_get_timestamp)

  local updated_request
  updated_request=$(echo "$request" | jq \
    --arg status "denied" \
    --arg decided_at "$decided_at" \
    --arg reason "$reason" \
    '. + {
      status: $status,
      decided_at: $decided_at,
      decision: {
        outcome: "denied",
        reason: (if $reason == "" then null else $reason end),
        decided_at: $decided_at
      }
    }')

  # Write to denied directory
  local denied_file="$DENIED_DIR/${approval_id}.json"
  echo "$updated_request" > "$denied_file"

  # Remove from pending
  rm -f "$pending_file"

  # Append to registry
  local agent_id
  agent_id=$(echo "$request" | jq -r '.agent_id')
  local approval_type
  approval_type=$(echo "$request" | jq -r '.type')

  local registry_entry
  registry_entry=$(jq -nc \
    --arg event "approval_denied" \
    --arg approval_id "$approval_id" \
    --arg approval_type "$approval_type" \
    --arg agent_id "$agent_id" \
    --arg decided_at "$decided_at" \
    --arg reason "$reason" \
    '{
      event: $event,
      approval_id: $approval_id,
      type: $approval_type,
      agent_id: $agent_id,
      decided_at: $decided_at,
      reason: (if $reason == "" then null else $reason end)
    }')
  _append_to_registry "$registry_entry"

  echo "[approval] Denied: $approval_id"
  return 0
}

# List all pending approvals with time remaining
# Returns: JSON array of pending approvals
list_pending_approvals() {
  _ensure_approval_dirs

  local now_epoch
  now_epoch=$(_get_epoch)

  local results="[]"

  # Iterate all pending approval files
  for pending_file in "$PENDING_DIR"/*.json; do
    # Skip if no files match
    [[ -e "$pending_file" ]] || continue

    local request
    request=$(cat "$pending_file")

    local approval_id approval_type timeout_at
    approval_id=$(echo "$request" | jq -r '.approval_id')
    approval_type=$(echo "$request" | jq -r '.type')
    timeout_at=$(echo "$request" | jq -r '.timeout_at')

    # Calculate time remaining
    local time_remaining stale_status
    if [[ "$timeout_at" == "$CRITICAL_TIMEOUT" ]]; then
      # Critical violations have infinite timeout
      time_remaining="infinite"
      stale_status="active"
    else
      local timeout_epoch
      timeout_epoch=$(_timestamp_to_epoch "$timeout_at")
      local remaining=$((timeout_epoch - now_epoch))
      time_remaining="$remaining"

      if [[ $remaining -lt 0 ]]; then
        stale_status="expired"
      elif [[ $remaining -lt $STALE_THRESHOLD_SECONDS ]]; then
        stale_status="stale"
      else
        stale_status="active"
      fi
    fi

    # Add entry with time remaining info
    local entry
    entry=$(echo "$request" | jq \
      --arg time_remaining "$time_remaining" \
      --arg stale_status "$stale_status" \
      '. + {time_remaining: $time_remaining, stale_status: $stale_status}')

    results=$(echo "$results" | jq --argjson entry "$entry" '. + [$entry]')
  done

  echo "$results" | jq .
}

# -----------------------------------------------------------------------------
# Stale Detection and Auto-Deny Functions
# -----------------------------------------------------------------------------

# Check for stale approvals (< 2 hours remaining)
# Returns: JSON array with stale status for each pending approval
check_stale_approvals() {
  _ensure_approval_dirs

  local now_epoch
  now_epoch=$(_get_epoch)

  local results="[]"

  # Iterate all pending approval files
  for pending_file in "$PENDING_DIR"/*.json; do
    # Skip if no files match
    [[ -e "$pending_file" ]] || continue

    local request
    request=$(cat "$pending_file")

    local approval_id approval_type timeout_at agent_id created_at
    approval_id=$(echo "$request" | jq -r '.approval_id')
    approval_type=$(echo "$request" | jq -r '.type')
    timeout_at=$(echo "$request" | jq -r '.timeout_at')
    agent_id=$(echo "$request" | jq -r '.agent_id')
    created_at=$(echo "$request" | jq -r '.created_at')

    # Skip critical violations (infinite timeout)
    if [[ "$approval_type" == "critical_violation" ]]; then
      local entry
      entry=$(jq -nc \
        --arg approval_id "$approval_id" \
        --arg type "$approval_type" \
        --arg agent_id "$agent_id" \
        --arg created_at "$created_at" \
        --arg status "active" \
        --arg time_remaining "infinite" \
        --arg note "critical violations never expire" \
        '{
          approval_id: $approval_id,
          type: $type,
          agent_id: $agent_id,
          created_at: $created_at,
          status: $status,
          time_remaining: $time_remaining,
          note: $note
        }')
      results=$(echo "$results" | jq --argjson entry "$entry" '. + [$entry]')
      continue
    fi

    # Calculate time remaining
    local timeout_epoch
    timeout_epoch=$(_timestamp_to_epoch "$timeout_at")
    local remaining=$((timeout_epoch - now_epoch))

    local status
    if [[ $remaining -lt 0 ]]; then
      status="expired"
    elif [[ $remaining -lt $STALE_THRESHOLD_SECONDS ]]; then
      status="stale"
    else
      status="active"
    fi

    # Format time remaining for humans
    local hours_remaining minutes_remaining
    if [[ $remaining -gt 0 ]]; then
      hours_remaining=$((remaining / 3600))
      minutes_remaining=$(((remaining % 3600) / 60))
    else
      hours_remaining=0
      minutes_remaining=0
    fi

    local entry
    entry=$(jq -nc \
      --arg approval_id "$approval_id" \
      --arg type "$approval_type" \
      --arg agent_id "$agent_id" \
      --arg created_at "$created_at" \
      --arg timeout_at "$timeout_at" \
      --arg status "$status" \
      --arg time_remaining_seconds "$remaining" \
      --arg time_remaining_human "${hours_remaining}h ${minutes_remaining}m" \
      '{
        approval_id: $approval_id,
        type: $type,
        agent_id: $agent_id,
        created_at: $created_at,
        timeout_at: $timeout_at,
        status: $status,
        time_remaining_seconds: ($time_remaining_seconds | tonumber),
        time_remaining_human: $time_remaining_human
      }')
    results=$(echo "$results" | jq --argjson entry "$entry" '. + [$entry]')
  done

  echo "$results" | jq .
}

# Process all expired approvals (auto-deny)
# Skips critical_violation types which never expire
# Returns: count of auto-denied approvals
process_expired_approvals() {
  _ensure_approval_dirs

  local now_epoch
  now_epoch=$(_get_epoch)
  local count=0

  # Iterate all pending approval files
  for pending_file in "$PENDING_DIR"/*.json; do
    # Skip if no files match
    [[ -e "$pending_file" ]] || continue

    local request
    request=$(cat "$pending_file")

    local approval_id approval_type timeout_at
    approval_id=$(echo "$request" | jq -r '.approval_id')
    approval_type=$(echo "$request" | jq -r '.type')
    timeout_at=$(echo "$request" | jq -r '.timeout_at')

    # Skip critical violations (never auto-deny)
    if [[ "$approval_type" == "critical_violation" ]]; then
      continue
    fi

    # Check if expired
    local timeout_epoch
    timeout_epoch=$(_timestamp_to_epoch "$timeout_at")
    local remaining=$((timeout_epoch - now_epoch))

    if [[ $remaining -lt 0 ]]; then
      # Auto-deny this approval
      local decided_at
      decided_at=$(_get_timestamp)

      # Update request with auto-deny decision
      local updated_request
      updated_request=$(echo "$request" | jq \
        --arg status "denied" \
        --arg decided_at "$decided_at" \
        '. + {
          status: $status,
          decided_at: $decided_at,
          decision: {
            outcome: "denied",
            reason: "Auto-denied: timeout after 24 hours",
            decided_at: $decided_at,
            auto_denied: true
          }
        }')

      # Write to denied directory
      local denied_file="$DENIED_DIR/${approval_id}.json"
      echo "$updated_request" > "$denied_file"

      # Remove from pending
      rm -f "$pending_file"

      # Append to registry with auto_denied flag
      local agent_id
      agent_id=$(echo "$request" | jq -r '.agent_id')

      local registry_entry
      registry_entry=$(jq -nc \
        --arg event "approval_auto_denied" \
        --arg approval_id "$approval_id" \
        --arg approval_type "$approval_type" \
        --arg agent_id "$agent_id" \
        --arg decided_at "$decided_at" \
        --arg reason "Auto-denied: timeout after 24 hours" \
        --argjson auto_denied true \
        '{
          event: $event,
          approval_id: $approval_id,
          type: $approval_type,
          agent_id: $agent_id,
          decided_at: $decided_at,
          reason: $reason,
          auto_denied: $auto_denied
        }')
      _append_to_registry "$registry_entry"

      echo "[auto-deny] Expired approval auto-denied: $approval_id"
      count=$((count + 1))
    fi
  done

  echo "[process-expired] Auto-denied $count expired approvals"
  return 0
}

# Get approval context for a specific approval
# Arguments: approval_id
# Returns: JSON with approval details or null if not found
get_approval_context() {
  local approval_id="$1"

  if [[ -z "$approval_id" ]]; then
    echo "[error] Usage: get_approval_context <approval_id>" >&2
    return 1
  fi

  local pending_file="$PENDING_DIR/${approval_id}.json"
  local approved_file="$APPROVED_DIR/${approval_id}.json"
  local denied_file="$DENIED_DIR/${approval_id}.json"

  local request=""
  local location=""

  # Check each location
  if [[ -f "$pending_file" ]]; then
    request=$(cat "$pending_file")
    location="pending"
  elif [[ -f "$approved_file" ]]; then
    request=$(cat "$approved_file")
    location="approved"
  elif [[ -f "$denied_file" ]]; then
    request=$(cat "$denied_file")
    location="denied"
  else
    echo "null"
    return 1
  fi

  # Add time remaining for pending approvals
  local now_epoch
  now_epoch=$(_get_epoch)
  local timeout_at
  timeout_at=$(echo "$request" | jq -r '.timeout_at')
  local approval_type
  approval_type=$(echo "$request" | jq -r '.type')

  local time_remaining
  if [[ "$approval_type" == "critical_violation" ]]; then
    time_remaining="infinite"
  elif [[ "$location" == "pending" ]]; then
    local timeout_epoch
    timeout_epoch=$(_timestamp_to_epoch "$timeout_at")
    time_remaining=$((timeout_epoch - now_epoch))
  else
    time_remaining="N/A"
  fi

  # Return enriched context
  echo "$request" | jq \
    --arg location "$location" \
    --arg time_remaining "$time_remaining" \
    '. + {location: $location, time_remaining: $time_remaining}'
}

# -----------------------------------------------------------------------------
# Delegation Functions
# -----------------------------------------------------------------------------

# Non-delegatable approval types (require CEO direct action)
NON_DELEGATABLE_TYPES=("trust_promotion" "critical_violation")

# Check if delegation is allowed for an approval
# Arguments: approval_id delegate_name
# Returns: 0 if delegation allowed, 1 if not
check_delegation() {
  local approval_id="$1"
  local delegate_name="$2"

  # Read worker config for delegation settings
  local config_file=".worker/config.json"
  if [[ ! -f "$config_file" ]]; then
    echo "[error] Config file not found: $config_file" >&2
    return 1
  fi

  # Check if delegation is enabled
  local delegation_enabled
  delegation_enabled=$(jq -r '.delegation.enabled // false' "$config_file")
  if [[ "$delegation_enabled" != "true" ]]; then
    echo "[delegation] Delegation is disabled in config" >&2
    return 1
  fi

  # Get approval details
  local pending_file="$PENDING_DIR/${approval_id}.json"
  if [[ ! -f "$pending_file" ]]; then
    echo "[error] Approval not found in pending: $approval_id" >&2
    return 1
  fi

  local approval_type
  approval_type=$(jq -r '.type' "$pending_file")

  # Check if type is delegatable
  for non_delegatable in "${NON_DELEGATABLE_TYPES[@]}"; do
    if [[ "$approval_type" == "$non_delegatable" ]]; then
      echo "[delegation] Type '$approval_type' cannot be delegated" >&2
      return 1
    fi
  done

  # Check if delegate is authorized
  local delegate_authorized
  delegate_authorized=$(jq -r --arg name "$delegate_name" '.delegation.delegates // [] | index($name) != null' "$config_file")
  if [[ "$delegate_authorized" != "true" ]]; then
    echo "[delegation] '$delegate_name' is not an authorized delegate" >&2
    return 1
  fi

  # Check if type is in allowed_types
  local type_allowed
  type_allowed=$(jq -r --arg type "$approval_type" '.delegation.allowed_types // [] | index($type) != null' "$config_file")
  if [[ "$type_allowed" != "true" ]]; then
    echo "[delegation] Type '$approval_type' is not in allowed delegation types" >&2
    return 1
  fi

  echo "[delegation] Delegation allowed for $approval_id by $delegate_name"
  return 0
}

# Approve with delegation (delegated approval on behalf of CEO)
# Arguments: approval_id delegator delegate justification
# Returns: 0 on success, 1 on failure
approve_with_delegation() {
  local approval_id="$1"
  local delegator="$2"
  local delegate="$3"
  local justification="${4:-}"

  if [[ -z "$approval_id" || -z "$delegator" || -z "$delegate" ]]; then
    echo "[error] Usage: approve_with_delegation <approval_id> <delegator> <delegate> [justification]" >&2
    return 1
  fi

  # Verify delegation is allowed
  if ! check_delegation "$approval_id" "$delegate" 2>/dev/null; then
    echo "[error] Delegation not permitted for this approval" >&2
    return 1
  fi

  local pending_file="$PENDING_DIR/${approval_id}.json"

  # Read current request
  local request
  request=$(cat "$pending_file")

  # Add decision metadata with delegation details
  local decided_at
  decided_at=$(_get_timestamp)

  local updated_request
  updated_request=$(echo "$request" | jq \
    --arg status "approved" \
    --arg decided_at "$decided_at" \
    --arg justification "$justification" \
    --arg delegator "$delegator" \
    --arg delegate "$delegate" \
    '. + {
      status: $status,
      decided_at: $decided_at,
      decision: {
        outcome: "approved",
        justification: (if $justification == "" then null else $justification end),
        decided_at: $decided_at,
        delegated: true,
        delegated_by: $delegator,
        delegate: $delegate
      }
    }')

  # Write to approved directory
  local approved_file="$APPROVED_DIR/${approval_id}.json"
  echo "$updated_request" > "$approved_file"

  # Remove from pending
  rm -f "$pending_file"

  # Append to registry with delegation details
  local agent_id approval_type
  agent_id=$(echo "$request" | jq -r '.agent_id')
  approval_type=$(echo "$request" | jq -r '.type')

  local registry_entry
  registry_entry=$(jq -nc \
    --arg event "approval_approved_delegated" \
    --arg approval_id "$approval_id" \
    --arg approval_type "$approval_type" \
    --arg agent_id "$agent_id" \
    --arg decided_at "$decided_at" \
    --arg justification "$justification" \
    --arg delegator "$delegator" \
    --arg delegate "$delegate" \
    '{
      event: $event,
      approval_id: $approval_id,
      type: $approval_type,
      agent_id: $agent_id,
      decided_at: $decided_at,
      justification: (if $justification == "" then null else $justification end),
      delegated_by: $delegator,
      delegate: $delegate
    }')
  _append_to_registry "$registry_entry"

  echo "[approval] Approved (delegated): $approval_id by $delegate on behalf of $delegator"
  return 0
}

# Get delegation status
# Returns: JSON with delegation configuration
get_delegation_status() {
  local config_file=".worker/config.json"

  if [[ ! -f "$config_file" ]]; then
    echo '{"enabled": false, "error": "config not found"}'
    return 1
  fi

  jq '{
    delegation_enabled: (.delegation.enabled // false),
    delegates: (.delegation.delegates // []),
    allowed_types: (.delegation.allowed_types // []),
    non_delegatable: ["trust_promotion", "critical_violation"]
  }' "$config_file"
}

# -----------------------------------------------------------------------------
# CLI Interface
# -----------------------------------------------------------------------------

# Show help message
_show_help() {
  cat <<'HELP'
approval-workflow.sh - File-based approval state management

USAGE:
  approval-workflow.sh <command> [arguments]

COMMANDS:
  create <type> <agent_id> [context_json]
      Create a new approval request
      Types: trust_promotion, critical_violation, scope_access, cross_workspace

  approve <approval_id> [justification]
      Approve a pending request

  deny <approval_id> [reason]
      Deny a pending request

  list
      List all pending approvals with time remaining

  check-stale
      Check for stale/expired approvals

  process-expired
      Auto-deny all expired approvals (skips critical_violation)

  context <approval_id>
      Get details for a specific approval

  delegation-status
      Show delegation configuration

  approve-delegated <approval_id> <delegator> <delegate> [justification]
      Approve via delegation (for authorized delegates)

  help
      Show this help message

EXAMPLES:
  # Create an approval request
  ./approval-workflow.sh create trust_promotion agent-1 '{"current":2,"target":3}'

  # List pending approvals
  ./approval-workflow.sh list

  # Approve a request
  ./approval-workflow.sh approve approval-12345 "Performance criteria met"

  # Check for stale approvals
  ./approval-workflow.sh check-stale

  # Process expired approvals (auto-deny)
  ./approval-workflow.sh process-expired
HELP
}

# CLI entry point - only runs when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    create)
      create_approval_request "$2" "$3" "${4:-"{}"}"
      ;;
    approve)
      approve_request "$2" "${3:-}"
      ;;
    deny)
      deny_request "$2" "${3:-}"
      ;;
    list)
      list_pending_approvals
      ;;
    check-stale)
      check_stale_approvals
      ;;
    process-expired)
      process_expired_approvals
      ;;
    context)
      get_approval_context "$2"
      ;;
    delegation-status)
      get_delegation_status
      ;;
    approve-delegated)
      approve_with_delegation "$2" "$3" "$4" "${5:-}"
      ;;
    help|--help|-h)
      _show_help
      ;;
    *)
      echo "Usage: $0 {create|approve|deny|list|check-stale|process-expired|context|delegation-status|approve-delegated|help}" >&2
      echo "Run '$0 help' for detailed usage information." >&2
      exit 1
      ;;
  esac
fi

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

# Guard against re-sourcing
[[ -n "${_APPROVAL_WORKFLOW_SOURCED:-}" ]] && return 0
_APPROVAL_WORKFLOW_SOURCED=1

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

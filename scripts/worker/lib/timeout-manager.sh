#!/usr/bin/env bash

# Timeout Manager Library
# Provides soft-then-hard timeout enforcement with bounded extension handling
# for worker sub-agents.

# Include guard - prevent multiple sourcing
[[ -n "${_TIMEOUT_MANAGER_SOURCED:-}" ]] && return 0
_TIMEOUT_MANAGER_SOURCED=1

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Constants
readonly SOFT_TIMEOUT_PERCENT=80
readonly MIN_GRACE_PERIOD=5
readonly MAX_EXTENSION_SECONDS=120
readonly MAX_EXTENSIONS_PER_AGENT=2
readonly AUTO_APPROVE_TRUST_LEVEL=3

# Global flag for graceful shutdown
SOFT_TIMEOUT_RECEIVED=0

# ==============================================================================
# Core Timeout Functions
# ==============================================================================

# Calculate timeouts from total budget
# Input: total_budget (seconds)
# Output: JSON with soft_timeout, grace_period, hard_timeout
calculate_timeouts() {
  local total_budget=$1

  # Soft timeout at 80% of budget
  local soft_timeout=$(( total_budget * SOFT_TIMEOUT_PERCENT / 100 ))

  # Grace period is remaining 20%, minimum 5 seconds
  local grace_period=$(( total_budget - soft_timeout ))
  if [ "$grace_period" -lt "$MIN_GRACE_PERIOD" ]; then
    grace_period=$MIN_GRACE_PERIOD
    # Adjust soft timeout if budget too small
    soft_timeout=$(( total_budget - grace_period ))
    if [ "$soft_timeout" -lt 1 ]; then
      soft_timeout=1
      grace_period=$(( total_budget - 1 ))
    fi
  fi

  local hard_timeout=$total_budget

  # Return as JSON
  cat <<EOF
{
  "soft_timeout": $soft_timeout,
  "grace_period": $grace_period,
  "hard_timeout": $hard_timeout
}
EOF
}

# Format duration as human-readable string
# Input: seconds
# Output: "Xm Ys" format
format_duration() {
  local seconds=$1
  local minutes=$(( seconds / 60 ))
  local remaining_seconds=$(( seconds % 60 ))

  if [ "$minutes" -gt 0 ]; then
    echo "${minutes}m ${remaining_seconds}s"
  else
    echo "${seconds}s"
  fi
}

# Get remaining time from budget
# Uses SECONDS builtin which should be set at function/script start
# Input: original_budget
# Output: remaining seconds (can be negative if over budget)
get_remaining_time() {
  local original_budget=$1
  local elapsed=${SECONDS:-0}
  local remaining=$(( original_budget - elapsed ))
  echo "$remaining"
}

# Execute command with soft-then-hard timeout
# Inputs: time_budget (seconds), agent_id, command...
# Exit codes:
#   0: success
#   124: soft timeout (SIGTERM sent)
#   137: hard kill (SIGKILL sent after grace period)
#   other: command failure
execute_with_timeout() {
  local time_budget=$1
  local agent_id=$2
  shift 2
  local command=("$@")

  # Calculate timeouts
  local timeouts
  timeouts=$(calculate_timeouts "$time_budget")
  local soft_timeout
  soft_timeout=$(echo "$timeouts" | jq -r '.soft_timeout')
  local grace_period
  grace_period=$(echo "$timeouts" | jq -r '.grace_period')

  local start_time
  start_time=$(date +%s)

  # Log execution start
  echo "[$(date -Iseconds)] [timeout-manager] Starting command for agent '$agent_id'" >&2
  echo "[$(date -Iseconds)] [timeout-manager] Budget: $(format_duration "$time_budget"), Soft: $(format_duration "$soft_timeout"), Grace: $(format_duration "$grace_period")" >&2

  # Execute with timeout
  # -k: send SIGKILL after grace period if process still alive
  # First argument is soft timeout (SIGTERM), -k argument is grace period before SIGKILL
  local exit_code=0
  timeout -k "$grace_period" "$soft_timeout" "${command[@]}" || exit_code=$?

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Log outcome
  case $exit_code in
    0)
      echo "[$(date -Iseconds)] [timeout-manager] Command completed successfully for agent '$agent_id' in $(format_duration "$duration")" >&2
      ;;
    124)
      echo "[$(date -Iseconds)] [timeout-manager] Soft timeout reached for agent '$agent_id' after $(format_duration "$duration") (SIGTERM sent)" >&2
      ;;
    137)
      echo "[$(date -Iseconds)] [timeout-manager] Hard kill executed for agent '$agent_id' after $(format_duration "$duration") (SIGKILL sent)" >&2
      ;;
    *)
      echo "[$(date -Iseconds)] [timeout-manager] Command failed for agent '$agent_id' with exit code $exit_code after $(format_duration "$duration")" >&2
      ;;
  esac

  return $exit_code
}

# ==============================================================================
# Extension Management Functions
# ==============================================================================

# Initialize timeout state for agent
# Input: agent_id, initial_budget
# Creates: .worker/agents/{agent_id}/timeout.json
init_timeout_state() {
  local agent_id=$1
  local initial_budget=$2

  local agent_dir=".worker/agents/${agent_id}"
  mkdir -p "$agent_dir"

  local start_time
  start_time=$(date -Iseconds)

  # Create state file
  cat > "${agent_dir}/timeout.json" <<EOF
{
  "agent_id": "$agent_id",
  "start_time": "$start_time",
  "initial_budget": $initial_budget,
  "current_budget": $initial_budget,
  "extensions_granted": 0,
  "extensions_remaining": $MAX_EXTENSIONS_PER_AGENT,
  "total_extension_seconds": 0
}
EOF

  echo "[$(date -Iseconds)] [timeout-manager] Initialized timeout state for agent '$agent_id' with budget $(format_duration "$initial_budget")" >&2
}

# Update timeout state after extension
# Input: agent_id, extension_seconds
# Updates: .worker/agents/{agent_id}/timeout.json
update_timeout_state() {
  local agent_id=$1
  local extension_seconds=$2

  local state_file=".worker/agents/${agent_id}/timeout.json"

  if [ ! -f "$state_file" ]; then
    echo "[$(date -Iseconds)] [timeout-manager] ERROR: State file not found for agent '$agent_id'" >&2
    return 1
  fi

  # Read current state
  local current_budget
  current_budget=$(jq -r '.current_budget' "$state_file")
  local extensions_granted
  extensions_granted=$(jq -r '.extensions_granted' "$state_file")
  local total_extension_seconds
  total_extension_seconds=$(jq -r '.total_extension_seconds' "$state_file")

  # Calculate new values
  local new_budget=$(( current_budget + extension_seconds ))
  local new_extensions=$(( extensions_granted + 1 ))
  local new_total_extension=$(( total_extension_seconds + extension_seconds ))
  local new_remaining=$(( MAX_EXTENSIONS_PER_AGENT - new_extensions ))

  # Update state file
  jq \
    --arg budget "$new_budget" \
    --arg granted "$new_extensions" \
    --arg remaining "$new_remaining" \
    --arg total "$new_total_extension" \
    '.current_budget = ($budget | tonumber) |
     .extensions_granted = ($granted | tonumber) |
     .extensions_remaining = ($remaining | tonumber) |
     .total_extension_seconds = ($total | tonumber)' \
    "$state_file" > "${state_file}.tmp"

  mv "${state_file}.tmp" "$state_file"

  echo "[$(date -Iseconds)] [timeout-manager] Granted $(format_duration "$extension_seconds") extension to agent '$agent_id' (extensions: $new_extensions/$MAX_EXTENSIONS_PER_AGENT)" >&2
}

# Check if agent is eligible for more extensions
# Input: agent_id
# Returns: 0 if extensions remain, 1 if exhausted
check_extension_eligible() {
  local agent_id=$1
  local state_file=".worker/agents/${agent_id}/timeout.json"

  if [ ! -f "$state_file" ]; then
    echo "[$(date -Iseconds)] [timeout-manager] ERROR: State file not found for agent '$agent_id'" >&2
    return 1
  fi

  local extensions_remaining
  extensions_remaining=$(jq -r '.extensions_remaining' "$state_file")

  if [ "$extensions_remaining" -gt 0 ]; then
    return 0
  else
    return 1
  fi
}

# Request timeout extension with bounded approval
# Inputs: agent_id, current_budget, justification, trust_level
# Returns: approved extension seconds (0 if denied)
# Per CONTEXT.md:
#   - Max extension: 120 seconds (2 minutes)
#   - Max extensions per agent: 2
#   - Trust 3+: auto-approve up to 20% more time
#   - Trust < 3: require explicit approval (return 0 = denied by default)
request_timeout_extension() {
  local agent_id=$1
  local current_budget=$2
  local justification=$3
  local trust_level=${4:-0}

  echo "[$(date -Iseconds)] [timeout-manager] Extension request from agent '$agent_id': $justification" >&2

  # Check if agent is eligible for more extensions
  if ! check_extension_eligible "$agent_id"; then
    echo "[$(date -Iseconds)] [timeout-manager] Extension DENIED: agent '$agent_id' has exhausted all extensions" >&2
    echo "0"
    return 0
  fi

  # Calculate requested extension (20% of current budget, capped at max)
  local requested_extension=$(( current_budget * 20 / 100 ))
  if [ "$requested_extension" -gt "$MAX_EXTENSION_SECONDS" ]; then
    requested_extension=$MAX_EXTENSION_SECONDS
  fi

  # Apply trust level policy
  if [ "$trust_level" -ge "$AUTO_APPROVE_TRUST_LEVEL" ]; then
    # Trust 3+: Auto-approve
    echo "[$(date -Iseconds)] [timeout-manager] Extension APPROVED: $(format_duration "$requested_extension") (trust level $trust_level >= $AUTO_APPROVE_TRUST_LEVEL)" >&2
    update_timeout_state "$agent_id" "$requested_extension"
    echo "$requested_extension"
  else
    # Trust < 3: Require explicit approval (not implemented in this library - caller must handle)
    echo "[$(date -Iseconds)] [timeout-manager] Extension requires approval: trust level $trust_level < $AUTO_APPROVE_TRUST_LEVEL (returning 0)" >&2
    echo "0"
  fi
}

# ==============================================================================
# Signal Handling
# ==============================================================================

# Handle soft timeout signal (SIGTERM)
# Sets global flag for command to check
# Allows current atomic operation to complete
handle_timeout_signal() {
  echo "[$(date -Iseconds)] [timeout-manager] Soft timeout signal received, starting graceful shutdown" >&2
  SOFT_TIMEOUT_RECEIVED=1

  # Note: The actual graceful shutdown logic should be implemented by the command
  # being executed. This handler just sets the flag for them to check.
  # Commands should periodically check: [ "$SOFT_TIMEOUT_RECEIVED" -eq 1 ]
}

# Set up signal trap for graceful shutdown
setup_timeout_trap() {
  trap 'handle_timeout_signal' TERM
}

# ==============================================================================
# Library initialization
# ==============================================================================

# Set up trap when library is sourced (can be overridden by caller)
setup_timeout_trap

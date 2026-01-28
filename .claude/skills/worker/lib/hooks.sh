#!/usr/bin/env bash
# hooks.sh - Pre/post hook execution wrapper for trust guardrails
# Version: 1.0.0
# Provides: Command execution with validation and audit logging
#
# Usage:
#   source .claude/skills/worker/lib/hooks.sh
#   execute_with_hooks "backend-developer" 2 echo "hello world"
#   execute_with_hooks "backend-developer" 2 git push origin main
#
# Flow:
#   1. pre_hook validates command against guardrails
#   2. If blocked: log, show feedback, return 1
#   3. If confirm: request approval (TTY or GitHub)
#   4. If allowed: execute command
#   5. post_hook logs result and applies trust decay

set -euo pipefail

# Determine script directory and load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/validator.sh"
source "$SCRIPT_DIR/audit.sh"

# Default confirmation timeout (seconds)
DEFAULT_CONFIRMATION_TIMEOUT=30

###########################################
# execute_with_hooks
# Main wrapper - orchestrates pre/post hooks around command execution
# Arguments:
#   $1 - agent name
#   $2 - trust level (0-4)
#   $@ - command and arguments
# Returns:
#   Command exit code (or 1 if blocked)
###########################################
execute_with_hooks() {
  local agent="${1:-}"
  local trust_level="${2:-}"
  shift 2
  local command="$*"

  if [[ -z "${agent}" || -z "${trust_level}" || -z "${command}" ]]; then
    echo "ERROR: execute_with_hooks requires agent, trust_level, and command" >&2
    return 1
  fi

  # Track execution start time
  local start_time
  start_time=$(date +%s)

  # Pre-hook: validate command
  if ! pre_hook "${agent}" "${trust_level}" "${command}"; then
    # Blocked or denied - already logged in pre_hook
    return 1
  fi

  # Execute the command and capture output
  local exit_code=0
  local output=""

  # Execute and capture both stdout and stderr
  if output=$(eval "$command" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  # Calculate execution duration
  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Post-hook: log result
  post_hook "${agent}" "${command}" "${exit_code}" "${output}" "${duration}"

  return ${exit_code}
}

###########################################
# pre_hook
# Pre-execution validation
# Arguments:
#   $1 - agent name
#   $2 - trust level (0-4)
#   $3 - command to validate
# Returns:
#   0 if allowed, 1 if blocked/denied
###########################################
pre_hook() {
  local agent="${1:-}"
  local trust_level="${2:-}"
  local command="${3:-}"

  if [[ -z "${agent}" || -z "${trust_level}" || -z "${command}" ]]; then
    echo "ERROR: pre_hook requires agent, trust_level, and command" >&2
    return 1
  fi

  # Validate command against guardrails
  local validation_result
  validation_result=$(validate_command "${agent}" "${trust_level}" "${command}")

  # Parse validation result
  local action
  action=$(echo "${validation_result}" | jq -r '.action')
  local severity
  severity=$(echo "${validation_result}" | jq -r '.severity')
  local reason
  reason=$(echo "${validation_result}" | jq -r '.reason')
  local alternatives
  alternatives=$(echo "${validation_result}" | jq -r '.alternatives // [] | join(", ")')

  case "${action}" in
    block)
      # Format and display block message
      format_block_message "${severity}" "${command}" "${reason}" "${alternatives}"

      # Log to audit trail
      log_audit_event "command_blocked" \
        --arg agent "${agent}" \
        --arg trust_level "${trust_level}" \
        --arg command "${command}" \
        --arg severity "${severity}" \
        --arg reason "${reason}"

      # Record violation
      record_violation "${agent}" "${command}" "blocked" "${severity}"

      return 1
      ;;

    confirm)
      # Format and display confirmation prompt
      format_confirm_message "${severity}" "${command}" "${reason}" "${DEFAULT_CONFIRMATION_TIMEOUT}"

      # Request confirmation
      if confirm_with_timeout "${DEFAULT_CONFIRMATION_TIMEOUT}"; then
        # Approved
        log_audit_event "command_confirmed" \
          --arg agent "${agent}" \
          --arg trust_level "${trust_level}" \
          --arg command "${command}" \
          --arg severity "${severity}" \
          --arg reason "${reason}"
        return 0
      else
        # Denied or timeout
        log_audit_event "command_denied" \
          --arg agent "${agent}" \
          --arg trust_level "${trust_level}" \
          --arg command "${command}" \
          --arg severity "${severity}" \
          --arg reason "confirmation_timeout_or_denied"

        # Record as violation (user had to intervene)
        record_violation "${agent}" "${command}" "confirmation_denied" "${severity}"

        return 1
      fi
      ;;

    allow)
      # Log allowed command
      log_audit_event "command_allowed" \
        --arg agent "${agent}" \
        --arg trust_level "${trust_level}" \
        --arg command "${command}" \
        --arg severity "${severity}"

      return 0
      ;;

    *)
      echo "ERROR: Unknown validation action: ${action}" >&2
      return 1
      ;;
  esac
}

###########################################
# post_hook
# Post-execution logging
# Arguments:
#   $1 - agent name
#   $2 - command executed
#   $3 - exit code
#   $4 - output (truncated)
#   $5 - duration (seconds)
# Returns:
#   0 (always succeeds)
###########################################
post_hook() {
  local agent="${1:-}"
  local command="${2:-}"
  local exit_code="${3:-0}"
  local output="${4:-}"
  local duration="${5:-0}"

  if [[ -z "${agent}" || -z "${command}" ]]; then
    echo "ERROR: post_hook requires agent and command" >&2
    return 0  # Don't fail execution on logging error
  fi

  # Truncate output for logging
  local output_length=${#output}
  local output_preview=""
  if (( output_length > 500 )); then
    output_preview="${output:0:500}... (truncated)"
  else
    output_preview="${output}"
  fi

  # Log based on exit code
  if [[ "${exit_code}" == "0" ]]; then
    # Success
    log_audit_event "command_completed" \
      --arg agent "${agent}" \
      --arg command "${command}" \
      --arg exit_code "${exit_code}" \
      --arg output_length "${output_length}" \
      --arg duration "${duration}"

    # Apply trust decay (reward clean action)
    apply_trust_decay "${agent}" >/dev/null
  else
    # Failure
    log_audit_event "command_failed" \
      --arg agent "${agent}" \
      --arg command "${command}" \
      --arg exit_code "${exit_code}" \
      --arg output_length "${output_length}" \
      --arg duration "${duration}" \
      --arg output_preview "${output_preview}"
  fi

  return 0
}

###########################################
# confirm_with_timeout
# Confirmation gate with timeout
# Arguments:
#   $1 - timeout in seconds
# Returns:
#   0 if approved, 1 if denied/timeout
###########################################
confirm_with_timeout() {
  local timeout="${1:-${DEFAULT_CONFIRMATION_TIMEOUT}}"

  # Check if we have a TTY (interactive terminal)
  if [[ -t 0 ]]; then
    # Interactive mode - use read with timeout
    local response=""

    echo -n "Approve? (y/N): "

    # Use read with timeout
    if read -t "${timeout}" -r response; then
      # Got input within timeout
      if [[ "${response}" =~ ^[yY]$ ]]; then
        echo "Approved."
        return 0
      else
        echo "Denied."
        return 1
      fi
    else
      # Timeout or read error
      echo ""
      echo "Timeout - denied by default."
      return 1
    fi
  else
    # Non-TTY mode - cannot prompt interactively
    echo "ERROR: Non-interactive mode - cannot confirm without TTY" >&2
    echo "Denied by default." >&2
    return 1
  fi
}

###########################################
# format_block_message
# Format block message for display
# Arguments:
#   $1 - severity (critical|high|medium|low)
#   $2 - command
#   $3 - reason
#   $4 - alternatives (comma-separated or empty)
# Returns:
#   void (prints to stdout)
###########################################
format_block_message() {
  local severity="${1:-low}"
  local command="${2:-}"
  local reason="${3:-}"
  local alternatives="${4:-}"

  # Severity markers (no emojis for Windows compatibility)
  local severity_marker
  case "${severity}" in
    critical) severity_marker="[CRITICAL]" ;;
    high)     severity_marker="[HIGH]" ;;
    medium)   severity_marker="[MEDIUM]" ;;
    low)      severity_marker="[LOW]" ;;
    *)        severity_marker="[UNKNOWN]" ;;
  esac

  echo ""
  echo "============================================"
  echo "COMMAND BLOCKED ${severity_marker}"
  echo "============================================"
  echo ""
  echo "Command: ${command}"
  echo "Reason:  ${reason}"

  if [[ -n "${alternatives}" && "${alternatives}" != "[]" ]]; then
    echo ""
    echo "Alternatives:"
    echo "  ${alternatives}"
  fi

  echo ""
  echo "Escalation: Contact project admin to adjust"
  echo "            trust level or guardrails config."
  echo "============================================"
  echo ""
}

###########################################
# format_confirm_message
# Format confirmation prompt for display
# Arguments:
#   $1 - severity (critical|high|medium|low)
#   $2 - command
#   $3 - reason
#   $4 - timeout (seconds)
# Returns:
#   void (prints to stdout)
###########################################
format_confirm_message() {
  local severity="${1:-low}"
  local command="${2:-}"
  local reason="${3:-}"
  local timeout="${4:-30}"

  # Severity markers
  local severity_marker
  case "${severity}" in
    critical) severity_marker="[CRITICAL]" ;;
    high)     severity_marker="[HIGH]" ;;
    medium)   severity_marker="[MEDIUM]" ;;
    low)      severity_marker="[LOW]" ;;
    *)        severity_marker="[UNKNOWN]" ;;
  esac

  echo ""
  echo "============================================"
  echo "CONFIRMATION REQUIRED ${severity_marker}"
  echo "============================================"
  echo ""
  echo "Command: ${command}"
  echo "Reason:  ${reason}"
  echo ""
  echo "Timeout: ${timeout} seconds"
  echo "Default: Deny (safe default)"
  echo "============================================"
  echo ""
}

###########################################
# request_github_approval
# Post approval request to GitHub issue
# Arguments:
#   $1 - issue number
#   $2 - command
#   $3 - reason
# Returns:
#   comment ID (for polling)
###########################################
request_github_approval() {
  local issue="${1:-}"
  local command="${2:-}"
  local reason="${3:-}"

  if [[ -z "${issue}" || -z "${command}" ]]; then
    echo "ERROR: request_github_approval requires issue and command" >&2
    return 1
  fi

  # Create approval request comment
  local comment_body
  comment_body=$(cat <<EOF
## Approval Required

**Command:** \`${command}\`

**Reason:** ${reason}

**Action:** React with :+1: to approve, :-1: to deny.

**Timeout:** Will auto-deny after 5 minutes.
EOF
)

  # Post comment and get comment ID
  local response
  if ! response=$(gh api repos/:owner/:repo/issues/"${issue}"/comments \
    -f body="${comment_body}" 2>&1); then
    echo "ERROR: Failed to post approval request: ${response}" >&2
    return 1
  fi

  local comment_id
  comment_id=$(echo "${response}" | jq -r '.id')

  echo "${comment_id}"
  return 0
}

###########################################
# check_github_approval
# Check for approval reaction on comment
# Arguments:
#   $1 - issue number
#   $2 - comment ID
# Returns:
#   0 if approved, 1 if not
###########################################
check_github_approval() {
  local issue="${1:-}"
  local comment_id="${2:-}"

  if [[ -z "${issue}" || -z "${comment_id}" ]]; then
    echo "ERROR: check_github_approval requires issue and comment_id" >&2
    return 1
  fi

  # Query reactions on comment
  local reactions
  if ! reactions=$(gh api repos/:owner/:repo/issues/comments/"${comment_id}"/reactions 2>&1); then
    echo "ERROR: Failed to get reactions: ${reactions}" >&2
    return 1
  fi

  # Check for thumbs up (+1)
  local thumbs_up_count
  thumbs_up_count=$(echo "${reactions}" | jq '[.[] | select(.content == "+1")] | length')

  if (( thumbs_up_count > 0 )); then
    return 0  # Approved
  else
    return 1  # Not approved
  fi
}

# Export functions for use in other scripts
export -f execute_with_hooks
export -f pre_hook
export -f post_hook
export -f confirm_with_timeout
export -f format_block_message
export -f format_confirm_message
export -f request_github_approval
export -f check_github_approval

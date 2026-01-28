#!/usr/bin/env bash
# scripts/orchestrator/intent.sh
# Intent classification helper for orchestrator
#
# Classifies CEO input into categories:
#   DISPATCH     - Action words (build, implement, create, add, fix, update, deploy, ship)
#   STATUS       - Query words (status, progress, what's, how's, show, list, report)
#   DECISION     - Decision references (blocked, waiting, decide, approve, review, choose)
#   CORRECTION   - Stop/pause words (stop, pause, cancel, abort, halt, wait)
#   CONVERSATION - Default for ambiguous input
#
# Usage:
#   scripts/orchestrator/intent.sh "build the login page"
#   echo "what's the status" | scripts/orchestrator/intent.sh
#
# Returns:
#   Prints classification to stdout and exits 0

set -euo pipefail

# -----------------------------------------------------------------------------
# classify_intent - Classify a message into intent categories
#
# Arguments:
#   $1 - Message to classify
#
# Returns:
#   Prints one of: DISPATCH, STATUS, DECISION, CORRECTION, CONVERSATION
# -----------------------------------------------------------------------------
classify_intent() {
  local message="$1"

  # Convert to lowercase for case-insensitive matching
  local lower_message
  lower_message=$(printf '%s' "$message" | tr '[:upper:]' '[:lower:]')

  # Fast semantic routing using grep patterns

  # Action words -> DISPATCH
  # Build, implement, create, add, fix, update, deploy, ship, make, set up, configure
  if printf '%s' "$lower_message" | grep -qE "(build|implement|create|add|fix|update|deploy|ship|make|configure)"; then
    printf 'DISPATCH\n'
    return 0
  fi

  # Query words -> STATUS
  # Status, progress, what's, how's, show, list, report, where, which
  if printf '%s' "$lower_message" | grep -qE "(status|progress|show|list|report|where|which|what|how)"; then
    printf 'STATUS\n'
    return 0
  fi

  # Decision references -> DECISION
  # Blocked, waiting, decide, approve, review, choose, pick, select
  if printf '%s' "$lower_message" | grep -qE "(blocked|waiting|decide|approve|review|choose|pick|select)"; then
    printf 'DECISION\n'
    return 0
  fi

  # Stop/pause words -> CORRECTION
  # Stop, pause, cancel, abort, halt, wait, hold, delay, postpone
  if printf '%s' "$lower_message" | grep -qE "(stop|pause|cancel|abort|halt|hold|delay|postpone)"; then
    printf 'CORRECTION\n'
    return 0
  fi

  # Default -> CONVERSATION (needs clarification)
  printf 'CONVERSATION\n'
  return 0
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  local message=""

  # Accept message from argument or stdin
  if [ $# -ge 1 ]; then
    message="$1"
  elif [ ! -t 0 ]; then
    # Read from stdin if not a terminal
    read -r message
  else
    printf 'Usage: %s "message" or echo "message" | %s\n' "$0" "$0" >&2
    exit 1
  fi

  # Classify and output
  classify_intent "$message"
}

# Run main when executed
main "$@"

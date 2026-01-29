#!/usr/bin/env bash
set -euo pipefail

# Sub-agent Scope Library
# Provides hierarchical identity generation and constraint derivation for worker parallelization

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MAX_NESTING_DEPTH=2

# ============================================================================
# Identity Generation Functions
# ============================================================================

# Slugify task name to URL-safe format
# Args: task_name
# Returns: lowercase slug with hyphens, alphanumeric only, max 30 chars
slugify_task_name() {
  local task_name="$1"

  # Convert to lowercase, replace spaces/underscores with hyphens
  local slug
  slug=$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' _' '--')

  # Remove non-alphanumeric except hyphens
  slug=$(echo "$slug" | tr -cd 'a-z0-9-')

  # Remove duplicate hyphens
  slug=$(echo "$slug" | sed 's/--*/-/g')

  # Remove leading/trailing hyphens
  slug=$(echo "$slug" | sed 's/^-//;s/-$//')

  # Truncate to 30 chars
  slug=$(echo "$slug" | cut -c1-30)

  echo "$slug"
}

# Generate hierarchical agent identity
# Args: parent_id (empty string for root), wave_num, task_name
# Returns: hierarchical agent ID in format {parent_id}/w{wave}-{task_slug}-{hash}
# Examples:
#   - Root: "worker-a1b2c3d4"
#   - Sub-agent: "worker-a1b2c3d4/w2-user-model-x7f3e2d1"
#   - Sub-sub-agent: "worker-a1b2c3d4/w2-user-model-x7f3/w1-validation-q2n5a8b7"
generate_agent_id() {
  local parent_id="$1"
  local wave_num="$2"
  local task_name="$3"

  # Generate short hash from PID + timestamp + random
  local short_hash
  short_hash=$(echo "$$-$(date +%s%N)-$RANDOM" | sha256sum | cut -c1-8)

  if [ -z "$parent_id" ]; then
    # Root worker - no parent
    echo "worker-${short_hash}"
  else
    # Sub-agent - append to parent hierarchy
    local task_slug
    task_slug=$(slugify_task_name "$task_name")
    echo "${parent_id}/w${wave_num}-${task_slug}-${short_hash}"
  fi
}

# Extract depth from agent ID by counting slashes
# Args: agent_id
# Returns: numeric depth (0=root, 1=sub-agent, 2=sub-sub-agent)
get_agent_depth() {
  local agent_id="$1"

  # Count '/' characters
  local depth
  depth=$(echo "$agent_id" | tr -cd '/' | wc -c)

  echo "$depth"
}

# Check if agent can spawn sub-agents (enforce max depth)
# Args: agent_id
# Returns: 0 if spawning allowed, 1 if at limit
# Logs error message when limit reached
check_nesting_limit() {
  local agent_id="$1"

  local depth
  depth=$(get_agent_depth "$agent_id")

  if [ "$depth" -ge "$MAX_NESTING_DEPTH" ]; then
    echo "[error] Maximum nesting depth ($MAX_NESTING_DEPTH) reached for agent: $agent_id" >&2
    echo "[error] Cannot spawn sub-agents at depth $depth" >&2
    return 1
  fi

  return 0
}

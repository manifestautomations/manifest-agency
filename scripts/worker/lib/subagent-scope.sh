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

# ============================================================================
# Constraint Derivation Functions
# ============================================================================

# Check if a file/pattern matches a glob pattern
# Args: file_pattern, glob_pattern
# Returns: 0 if matches, 1 if not
matches_glob() {
  local file_pattern="$1"
  local glob_pattern="$2"

  # Simple glob matching using case statement
  # Supports * and ** wildcards
  # Replace ** with * for bash pattern matching
  local bash_pattern="${glob_pattern//\*\*/\*}"

  case "$file_pattern" in
    $bash_pattern) return 0 ;;
    *) return 1 ;;
  esac
}

# Validate that child scope is a subset of parent scope
# Args: child_scope_json (JSON array), parent_scope_json (JSON array)
# Returns: 0 if valid subset, 1 if exceeds parent
# Logs specific files that exceed scope on failure
# Note: Parent scope may contain globs, child files must match at least one parent glob
validate_scope_subset() {
  local child_scope_json="$1"
  local parent_scope_json="$2"

  # Convert JSON arrays to arrays
  local child_files parent_patterns
  readarray -t child_files < <(echo "$child_scope_json" | jq -r '.[]' 2>/dev/null)
  readarray -t parent_patterns < <(echo "$parent_scope_json" | jq -r '.[]' 2>/dev/null)

  # Check each child file/pattern against parent patterns
  local invalid_files=()
  for child_file in "${child_files[@]}"; do
    [ -z "$child_file" ] && continue

    local matched=false
    for parent_pattern in "${parent_patterns[@]}"; do
      [ -z "$parent_pattern" ] && continue

      # Check if child exactly matches parent
      if [ "$child_file" = "$parent_pattern" ]; then
        matched=true
        break
      fi

      # Check if child matches parent glob
      if matches_glob "$child_file" "$parent_pattern"; then
        matched=true
        break
      fi
    done

    if [ "$matched" = false ]; then
      invalid_files+=("$child_file")
    fi
  done

  if [ ${#invalid_files[@]} -gt 0 ]; then
    echo "[error] Task scope exceeds parent scope. Invalid files:" >&2
    for file in "${invalid_files[@]}"; do
      echo "  - $file" >&2
    done
    return 1
  fi

  return 0
}

# Derive sub-agent constraints from parent constraints and task scope
# Args: parent_constraints_file (JSON file path), task_declared_scope (JSON string)
# Returns: JSON to stdout with derived constraints, or exits 1 on error
# Output includes: scope, trust_level, parent_ceiling, agent_id, depth
derive_subagent_constraints() {
  local parent_constraints_file="$1"
  local task_declared_scope="$2"

  # Validate parent constraints file exists
  if [ ! -f "$parent_constraints_file" ]; then
    echo "[error] Parent constraints file not found: $parent_constraints_file" >&2
    return 1
  fi

  # Load parent constraints
  local parent_constraints
  if ! parent_constraints=$(cat "$parent_constraints_file" 2>/dev/null); then
    echo "[error] Failed to read parent constraints file" >&2
    return 1
  fi

  # Validate JSON
  if ! echo "$parent_constraints" | jq empty 2>/dev/null; then
    echo "[error] Invalid JSON in parent constraints file" >&2
    return 1
  fi

  # Extract parent scope and trust level
  local parent_read parent_write parent_trust
  parent_read=$(echo "$parent_constraints" | jq '.scope.read // []')
  parent_write=$(echo "$parent_constraints" | jq '.scope.write // []')
  parent_trust=$(echo "$parent_constraints" | jq -r '.trust_level // 2')

  # Parse task declared scope (may be empty)
  local task_read task_write
  if [ -n "$task_declared_scope" ] && [ "$task_declared_scope" != "null" ]; then
    if ! echo "$task_declared_scope" | jq empty 2>/dev/null; then
      echo "[error] Invalid JSON in task declared scope" >&2
      return 1
    fi
    task_read=$(echo "$task_declared_scope" | jq '.read_scope // []')
    task_write=$(echo "$task_declared_scope" | jq '.write_scope // []')
  else
    # No task scope declared - inherit parent scope
    task_read="[]"
    task_write="[]"
  fi

  # Validate task write scope is subset of parent write scope
  if [ "$task_write" != "[]" ] && [ "$task_write" != "null" ]; then
    if ! validate_scope_subset "$task_write" "$parent_write"; then
      echo "[error] Scope escalation detected - task write scope exceeds parent" >&2
      return 1
    fi
  fi

  # Validate task read scope is subset of parent read scope
  if [ "$task_read" != "[]" ] && [ "$task_read" != "null" ]; then
    if ! validate_scope_subset "$task_read" "$parent_read"; then
      echo "[error] Scope escalation detected - task read scope exceeds parent" >&2
      return 1
    fi
  fi

  # Use task scope if declared, otherwise inherit parent scope
  local derived_read derived_write
  if [ "$task_read" != "[]" ] && [ "$task_read" != "null" ]; then
    derived_read="$task_read"
  else
    derived_read="$parent_read"
  fi

  if [ "$task_write" != "[]" ] && [ "$task_write" != "null" ]; then
    derived_write="$task_write"
  else
    derived_write="$parent_write"
  fi

  # Generate derived constraints JSON
  jq -n \
    --argjson read "$derived_read" \
    --argjson write "$derived_write" \
    --arg trust "$parent_trust" \
    --argjson parent_write "$parent_write" \
    '{
      scope: {
        read: $read,
        write: $write
      },
      trust_level: ($trust | tonumber),
      parent_ceiling: {
        write: $parent_write
      }
    }'
}

# ============================================================================
# Context Bundle Functions
# ============================================================================

# Create context bundle for sub-agent
# Args: agent_id, task_json, constraints_json
# Returns: path to context directory
# Creates: .worker/agents/{agent_id}/context.json, constraints.json, parent_summary.md
create_context_bundle() {
  local agent_id="$1"
  local task_json="$2"
  local constraints_json="$3"

  # Create agent directory
  local agent_dir=".worker/agents/${agent_id}"
  mkdir -p "$agent_dir"

  # Write context.json (task specifics)
  echo "$task_json" | jq '.' > "${agent_dir}/context.json"

  # Write constraints.json
  echo "$constraints_json" | jq '.' > "${agent_dir}/constraints.json"

  # Create parent_summary.md (brief orientation)
  local task_name
  task_name=$(echo "$task_json" | jq -r '.name // "Unknown Task"')

  local depth
  depth=$(get_agent_depth "$agent_id")

  cat > "${agent_dir}/parent_summary.md" <<EOF
# Sub-Agent Context

**Agent ID:** \`${agent_id}\`
**Task:** ${task_name}
**Depth:** ${depth}

## Scope

This sub-agent has been spawned to execute a specific task with scoped constraints
inherited from the parent worker. All file operations must stay within the declared
scope to prevent conflicts with parallel agents.

## Constraints

See \`constraints.json\` for detailed scope and trust level information.

## Task Details

See \`context.json\` for task-specific requirements and context.
EOF

  echo "$agent_dir"
}

# ============================================================================
# Agent Registry Functions
# ============================================================================

# Register agent in the global registry
# Args: agent_id, parent_id, status (default: "spawned")
# Creates/updates: .worker/agents/registry.yaml
register_agent() {
  local agent_id="$1"
  local parent_id="$2"
  local status="${3:-spawned}"

  local registry_file=".worker/agents/registry.yaml"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create registry directory if needed
  mkdir -p .worker/agents

  # Initialize registry if it doesn't exist
  if [ ! -f "$registry_file" ]; then
    echo "agents: []" > "$registry_file"
  fi

  # Check if yq is available
  if ! command -v yq &> /dev/null; then
    echo "[warning] yq not found - cannot update registry" >&2
    return 1
  fi

  # Add or update agent entry
  # Using yq to manipulate YAML
  local temp_file
  temp_file=$(mktemp)

  # Check if agent already exists
  if yq eval ".agents[] | select(.id == \"$agent_id\")" "$registry_file" | grep -q "id:"; then
    # Update existing entry
    yq eval "(.agents[] | select(.id == \"$agent_id\") | .status) = \"$status\" |
             (.agents[] | select(.id == \"$agent_id\") | .updated) = \"$timestamp\"" \
      "$registry_file" > "$temp_file"
  else
    # Add new entry
    yq eval ".agents += [{
      \"id\": \"$agent_id\",
      \"parent_id\": \"$parent_id\",
      \"status\": \"$status\",
      \"spawned\": \"$timestamp\",
      \"updated\": \"$timestamp\"
    }]" "$registry_file" > "$temp_file"
  fi

  mv "$temp_file" "$registry_file"

  echo "[registry] Agent registered: $agent_id (status: $status)"
}

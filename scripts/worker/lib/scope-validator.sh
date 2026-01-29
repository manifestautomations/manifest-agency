#!/usr/bin/env bash

# Scope Validator Library
# Pre-flight write conflict detection for parallel sub-agent execution
# Validates that write scopes don't overlap before spawning any agents in a wave

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$SCRIPT_DIR/subagent-scope.sh"

# ============================================================================
# Write Conflict Detection Functions
# ============================================================================

# Expand glob patterns to actual file list
# Args: scope_json (JSON array, may contain globs)
# Returns: expanded file list (one per line)
# Note: Globs that match no files are included as-is for conflict detection
expand_glob_scope() {
  local scope_json="$1"

  # Convert JSON array to lines
  local patterns
  readarray -t patterns < <(echo "$scope_json" | jq -r '.[]' 2>/dev/null)

  local expanded_files=()

  for pattern in "${patterns[@]}"; do
    [ -z "$pattern" ] && continue

    # Check if pattern contains glob characters
    if [[ "$pattern" == *"*"* ]] || [[ "$pattern" == *"?"* ]]; then
      # Expand glob
      local matches=()

      # Use bash globbing with nullglob
      shopt -s nullglob
      shopt -s globstar  # Enable ** for recursive matching

      # Expand the glob
      local files=($pattern)

      if [ ${#files[@]} -gt 0 ]; then
        # Glob matched files
        for file in "${files[@]}"; do
          expanded_files+=("$file")
        done
      else
        # No matches - include pattern as-is for conflict detection
        expanded_files+=("$pattern")
      fi

      shopt -u nullglob
      shopt -u globstar
    else
      # Literal file path
      expanded_files+=("$pattern")
    fi
  done

  # Output unique files
  printf '%s\n' "${expanded_files[@]}" | sort -u
}

# Detect write conflicts between multiple agents
# Args: constraint_files (JSON array of paths to agent constraint files)
# Returns: 0 if no conflicts, 1 if conflicts detected
# Outputs conflict details to stderr on detection
detect_write_conflicts() {
  local constraint_files_json="$1"

  # Build associative array: file -> list of agents writing to it
  declare -A file_writers

  # Parse constraint files
  local constraint_files
  readarray -t constraint_files < <(echo "$constraint_files_json" | jq -r '.[]' 2>/dev/null)

  for constraint_file in "${constraint_files[@]}"; do
    [ -z "$constraint_file" ] && continue

    if [ ! -f "$constraint_file" ]; then
      echo "[warning] Constraint file not found: $constraint_file" >&2
      continue
    fi

    # Extract agent ID from path (.worker/agents/{agent_id}/constraints.json)
    local agent_id
    agent_id=$(basename "$(dirname "$constraint_file")")

    # Get write scope for this agent
    local write_scope
    write_scope=$(jq '.scope.write // []' "$constraint_file" 2>/dev/null)

    # Expand globs
    local expanded_files
    expanded_files=$(expand_glob_scope "$write_scope")

    # Record each file this agent writes to
    while IFS= read -r file; do
      [ -z "$file" ] && continue

      # Append agent to file's writer list
      if [ -n "${file_writers[$file]:-}" ]; then
        file_writers[$file]+=" $agent_id"
      else
        file_writers[$file]="$agent_id"
      fi
    done <<< "$expanded_files"
  done

  # Check for conflicts (files with multiple writers)
  local conflicts_found=false
  local conflict_details=""

  for file in "${!file_writers[@]}"; do
    local writers="${file_writers[$file]}"
    local writer_count
    writer_count=$(echo "$writers" | wc -w | tr -d ' ')

    if [ "$writer_count" -gt 1 ]; then
      conflicts_found=true
      conflict_details+="File '$file' has multiple writers:$writers\n"
    fi
  done

  if [ "$conflicts_found" = true ]; then
    echo "[error] Write scope conflicts detected:" >&2
    echo -e "$conflict_details" >&2
    return 1
  fi

  return 0
}

# Validate wave scopes before dispatch (pre-flight check)
# Args: wave_id, task_definitions_json (JSON array of task objects with write_scope)
# Returns: 0 if no conflicts, 1 if conflicts found
# IMPORTANT: This MUST be called BEFORE spawning any agents in the wave
validate_wave_scopes() {
  local wave_id="$1"
  local task_definitions_json="$2"

  echo "[validate] Pre-flight scope validation for wave: $wave_id" >&2

  # Parse task definitions and extract write scopes
  local tasks
  readarray -t tasks < <(echo "$task_definitions_json" | jq -c '.[]' 2>/dev/null)

  if [ ${#tasks[@]} -eq 0 ]; then
    echo "[validate] No tasks in wave - nothing to validate" >&2
    return 0
  fi

  # Build temporary constraint files for validation
  local temp_dir
  temp_dir=$(mktemp -d)

  local constraint_files=()

  for i in "${!tasks[@]}"; do
    local task="${tasks[$i]}"

    # Extract task ID and write scope
    local task_id write_scope
    task_id=$(echo "$task" | jq -r '.id // .name // "task-'"$i"'"')
    write_scope=$(echo "$task" | jq '.write_scope // []')

    # Create temporary constraint file
    local temp_constraint="$temp_dir/${task_id}.json"
    jq -n \
      --argjson write "$write_scope" \
      '{scope: {write: $write}}' > "$temp_constraint"

    constraint_files+=("$temp_constraint")
  done

  # Build JSON array of constraint file paths
  local constraint_files_json
  constraint_files_json=$(jq -nc '$ARGS.positional' --args "${constraint_files[@]}")

  # Detect conflicts
  local result=0
  if ! detect_write_conflicts "$constraint_files_json"; then
    echo "[validate] Wave $wave_id FAILED pre-flight validation - conflicts detected" >&2
    result=1
  else
    echo "[validate] Wave $wave_id PASSED pre-flight validation - no conflicts" >&2
  fi

  # Clean up temp dir
  rm -rf "$temp_dir"

  return $result
}

# Query which agent writes to a specific file
# Args: file_path, wave_agents_json (JSON array of agent constraint file paths)
# Returns: agent_id that writes to the file, or empty if none
get_file_writer() {
  local file_path="$1"
  local wave_agents_json="$2"

  local constraint_files
  readarray -t constraint_files < <(echo "$wave_agents_json" | jq -r '.[]' 2>/dev/null)

  for constraint_file in "${constraint_files[@]}"; do
    [ -z "$constraint_file" ] && continue
    [ ! -f "$constraint_file" ] && continue

    # Extract agent ID
    local agent_id
    agent_id=$(basename "$(dirname "$constraint_file")")

    # Get write scope
    local write_scope
    write_scope=$(jq '.scope.write // []' "$constraint_file" 2>/dev/null)

    # Expand globs
    local expanded_files
    expanded_files=$(expand_glob_scope "$write_scope")

    # Check if file is in this agent's write scope
    while IFS= read -r scoped_file; do
      [ -z "$scoped_file" ] && continue

      # Check exact match or glob match
      if [ "$scoped_file" = "$file_path" ]; then
        echo "$agent_id"
        return 0
      fi

      # Check if scoped_file is a glob that matches file_path
      if matches_glob "$file_path" "$scoped_file"; then
        echo "$agent_id"
        return 0
      fi
    done <<< "$expanded_files"
  done

  # No writer found
  echo ""
  return 0
}

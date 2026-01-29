#!/usr/bin/env bash
# graph-parser.sh - Execution graph parser for worker parallelization
#
# Extracts and validates execution graphs from PLAN.md files.
# Supports YAML extraction, DAG validation, and task dependency queries.
#
# Usage:
#   source scripts/worker/lib/graph-parser.sh
#   yaml_block=$(extract_execution_graph "/path/to/PLAN.md")
#   deps=$(get_task_dependencies "task-1" "$yaml_block")
#   validate_dag "$yaml_block"
#   ready=$(get_ready_tasks "$yaml_block")
#
# Functions:
#   extract_execution_graph PLAN_FILE
#     - Extract YAML block from "## Execution Graph" section
#     - Returns YAML content, exits 1 if no graph found
#   get_task_dependencies TASK_ID YAML_BLOCK
#     - Get dependency list for a specific task
#     - Returns space-separated task IDs
#   get_task_property YAML_BLOCK TASK_ID PROPERTY
#     - Generic property accessor (id, name, write_scope, etc.)
#   list_all_tasks YAML_BLOCK
#     - Get all task IDs from graph
#     - Returns newline-separated task IDs
#   validate_dag YAML_BLOCK
#     - Validate no cycles using tsort
#     - Returns 0 if valid DAG, 1 if cycle detected
#   get_ready_tasks YAML_BLOCK
#     - Get tasks with no dependencies (Wave 1 candidates)
#   get_dependent_tasks TASK_ID YAML_BLOCK
#     - Get tasks that depend on given task (for cascade detection)
#   check_parallelization_threshold YAML_BLOCK
#     - Check if parallelization makes sense per CONTEXT.md rules
#     - Returns "parallel" or "serial" recommendation

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Core Functions ---

# Extract execution graph YAML from PLAN.md
# Arguments: plan_file_path
# Returns: YAML content (stdout), exits 1 if no graph found
extract_execution_graph() {
  local plan_file="$1"

  if [ ! -f "$plan_file" ]; then
    echo "[error] Plan file not found: $plan_file" >&2
    return 1
  fi

  # Find "## Execution Graph" section and extract YAML block
  # Pattern from RESEARCH.md: sed to extract between ```yaml and ``` fences
  local yaml_block
  yaml_block=$(sed -n '/^## Execution Graph/,/^##/p' "$plan_file" | \
               sed -n '/```yaml/,/```/p' | \
               sed '1d;$d')  # Remove fence markers

  if [ -z "$yaml_block" ]; then
    echo "[info] No execution graph found in $plan_file - will serialize" >&2
    return 1
  fi

  # Validate YAML syntax with yq
  if ! echo "$yaml_block" | yq eval '.' - >/dev/null 2>&1; then
    echo "[error] Invalid YAML in execution graph" >&2
    return 1
  fi

  echo "$yaml_block"
}

# Get dependencies for a specific task
# Arguments: task_id, yaml_block
# Returns: space-separated list of dependency task IDs
get_task_dependencies() {
  local task_id="$1"
  local yaml_block="$2"

  # Use yq to extract depends_on array for the task
  # Returns empty if no dependencies
  echo "$yaml_block" | yq eval ".tasks[] | select(.id == \"$task_id\") | .depends_on[]?" - 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
}

# Generic property accessor
# Arguments: yaml_block, task_id, property_name
# Returns: property value (string, array, etc.)
get_task_property() {
  local yaml_block="$1"
  local task_id="$2"
  local property_name="$3"

  # Extract property value for task
  echo "$yaml_block" | yq eval ".tasks[] | select(.id == \"$task_id\") | .$property_name" - 2>/dev/null
}

# List all task IDs from graph
# Arguments: yaml_block
# Returns: newline-separated task IDs
list_all_tasks() {
  local yaml_block="$1"

  # Extract all task IDs
  echo "$yaml_block" | yq eval '.tasks[].id' - 2>/dev/null
}

# --- DAG Validation Functions ---

# Validate no cycles in dependency graph
# Arguments: yaml_block
# Returns: 0 if valid DAG, 1 if cycle detected
validate_dag() {
  local yaml_block="$1"

  # Convert to tsort input format: "dependency dependent"
  # IMPORTANT: Format is "dependency dependent" (dependency must complete before dependent)
  # Pattern from scripts/orchestrator/graph.sh lines 66-67
  local edges
  edges=$(echo "$yaml_block" | yq eval '.tasks[] |
    .id as $task |
    .depends_on[]? |
    "\(.) \($task)"' - 2>/dev/null)

  # If no dependencies, it's a valid DAG
  if [ -z "$edges" ]; then
    return 0
  fi

  # Use tsort to detect cycles
  # tsort exits non-zero if cycle detected
  if echo "$edges" | tsort >/dev/null 2>&1; then
    return 0  # Valid DAG
  else
    echo "[error] Cycle detected in execution graph" >&2
    echo "[detail] Dependency edges:" >&2
    echo "$edges" | while read -r dep task; do
      echo "  Task $task depends on $dep" >&2
    done
    return 1
  fi
}

# Get tasks with no dependencies (Wave 1 candidates)
# Arguments: yaml_block
# Returns: newline-separated task IDs
get_ready_tasks() {
  local yaml_block="$1"

  # Get tasks where depends_on is null or empty array
  echo "$yaml_block" | yq eval '.tasks[] | select(.depends_on == null or (.depends_on | length) == 0) | .id' - 2>/dev/null
}

# Get tasks that depend on a given task
# Arguments: task_id, yaml_block
# Returns: newline-separated task IDs that depend on task_id
get_dependent_tasks() {
  local task_id="$1"
  local yaml_block="$2"

  # Find tasks that list task_id in their depends_on array
  echo "$yaml_block" | yq eval ".tasks[] | select(.depends_on[]? == \"$task_id\") | .id" - 2>/dev/null
}

# Check if parallelization makes sense
# Arguments: yaml_block
# Returns: "parallel" or "serial" recommendation
# Per CONTEXT.md: 3+ independent tasks OR 2 tasks with duration > 5 min
check_parallelization_threshold() {
  local yaml_block="$1"

  # Count tasks with no dependencies (Wave 1 candidates)
  local ready_count
  ready_count=$(get_ready_tasks "$yaml_block" | wc -l | tr -d ' ')

  # Check threshold: 3+ independent tasks
  if [ "$ready_count" -ge 3 ]; then
    echo "parallel"
    return 0
  fi

  # Check exception: 2 tasks with total duration > 5 minutes
  if [ "$ready_count" -eq 2 ]; then
    local total_duration=0
    local ready_tasks
    ready_tasks=$(get_ready_tasks "$yaml_block")

    while IFS= read -r task_id; do
      local duration
      duration=$(get_task_property "$yaml_block" "$task_id" "estimated_duration" | sed 's/[^0-9]//g')
      if [ -n "$duration" ]; then
        total_duration=$((total_duration + duration))
      fi
    done <<< "$ready_tasks"

    if [ "$total_duration" -gt 300 ]; then  # 5 minutes = 300 seconds
      echo "parallel"
      return 0
    fi
  fi

  # Default: serialize
  echo "serial"
}

# --- End of Functions ---

#!/usr/bin/env bash
# spawn-subagent.sh - Sub-agent spawner with PID tracking and wave management
#
# Core spawning logic for parallel sub-agent execution within workers.
# Validates scopes, manages concurrency, tracks PIDs, and aggregates results.
#
# Usage:
#   ./spawn-subagent.sh --spawn --parent worker-abc --task '{"id":"t1","name":"Build API"}'
#   ./spawn-subagent.sh --wave --parent worker-abc --tasks '[{"id":"t1",...},{"id":"t2",...}]'
#   ./spawn-subagent.sh --status [--agent agent-id]
#
# Functions (when sourced):
#   spawn_subagent parent_id task_json [background]
#     - Spawn single sub-agent with constraint validation
#   spawn_wave wave_tasks parent_id
#     - Spawn all agents in a wave with pre-flight validation
#   wait_for_subagent
#     - Wait for any sub-agent to complete (wait -n pattern)
#   get_subagent_status agent_id
#     - Query running/complete/failed status
#
# Dependencies:
#   - scripts/worker/lib/graph-parser.sh
#   - scripts/worker/lib/subagent-scope.sh
#   - scripts/worker/lib/timeout-manager.sh
#   - scripts/worker/lib/scope-validator.sh

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Default settings
MAX_CONCURRENT=3
DEFAULT_TIMEOUT=600  # 10 minutes

# --- Source Dependencies ---
source "$LIB_DIR/graph-parser.sh"
source "$LIB_DIR/subagent-scope.sh"
source "$LIB_DIR/timeout-manager.sh"
source "$LIB_DIR/scope-validator.sh"

# --- Tracking Data Structures ---
# Associative array: agent_id -> PID
declare -A subagent_pids=()
# Array of completed agent IDs
declare -a completed_agents=()
# Array of failed agent IDs
declare -a failed_agents=()

# --- Core Spawning Functions ---

# Spawn a single sub-agent
# Args: parent_id, task_json, [background (true|false, default true)]
# Returns: 0 on success, 1 on error
# If background=true: starts agent in background and tracks PID
# If background=false: runs synchronously and waits for completion
spawn_subagent() {
  local parent_id="$1"
  local task_json="$2"
  local background="${3:-true}"

  # Parse task information
  local task_id task_name
  task_id=$(echo "$task_json" | jq -r '.id // .name // "unknown"')
  task_name=$(echo "$task_json" | jq -r '.name // .id // "Unknown Task"')

  echo "[spawn] Spawning sub-agent for: $task_name (task: $task_id)" >&2

  # Generate agent ID
  local wave_num
  wave_num=$(echo "$task_json" | jq -r '.wave // 1')

  local agent_id
  agent_id=$(generate_agent_id "$parent_id" "$wave_num" "$task_name")

  echo "[spawn] Generated agent ID: $agent_id" >&2

  # Check nesting limit
  if ! check_nesting_limit "$parent_id"; then
    echo "[error] Cannot spawn sub-agent - nesting limit reached" >&2
    return 1
  fi

  # Load parent constraints
  local parent_constraints_file
  parent_constraints_file=".worker/agents/${parent_id}/constraints.json"

  if [ ! -f "$parent_constraints_file" ]; then
    echo "[error] Parent constraints not found: $parent_constraints_file" >&2
    return 1
  fi

  # Extract task declared scope
  local task_scope
  task_scope=$(echo "$task_json" | jq -c '{read_scope: .read_scope, write_scope: .write_scope}')

  # Derive sub-agent constraints
  local derived_constraints
  if ! derived_constraints=$(derive_subagent_constraints "$parent_constraints_file" "$task_scope"); then
    echo "[error] Failed to derive sub-agent constraints (scope escalation?)" >&2
    return 1
  fi

  # Create context bundle
  local agent_dir
  agent_dir=$(create_context_bundle "$agent_id" "$task_json" "$derived_constraints")

  # Register agent
  register_agent "$agent_id" "$parent_id" "spawning"

  # Extract command to execute
  local command
  command=$(echo "$task_json" | jq -r '.command // ""')

  if [ -z "$command" ]; then
    echo "[error] No command specified in task JSON" >&2
    return 1
  fi

  # Get timeout budget
  local timeout_budget
  timeout_budget=$(echo "$task_json" | jq -r '.timeout // '"$DEFAULT_TIMEOUT")

  echo "[spawn] Executing: $command (timeout: ${timeout_budget}s)" >&2

  # Execute with timeout
  if [ "$background" = "true" ]; then
    # Background execution - spawn and track PID
    (
      # Execute command with timeout in subshell
      if execute_with_timeout "$timeout_budget" "$command" "$agent_id"; then
        register_agent "$agent_id" "$parent_id" "complete"
        exit 0
      else
        local exit_code=$?
        register_agent "$agent_id" "$parent_id" "failed"
        exit $exit_code
      fi
    ) &

    # Capture PID immediately (critical for race condition prevention)
    local pid=$!
    subagent_pids[$agent_id]=$pid

    echo "[spawn] Sub-agent $agent_id running in background (PID: $pid)" >&2

    # Verify process still running (catch immediate failures)
    sleep 0.1
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "[warning] Sub-agent $agent_id exited immediately after spawn" >&2
    fi
  else
    # Synchronous execution - wait for completion
    if execute_with_timeout "$timeout_budget" "$command" "$agent_id"; then
      register_agent "$agent_id" "$parent_id" "complete"
      completed_agents+=("$agent_id")
      echo "[spawn] Sub-agent $agent_id completed successfully" >&2
      return 0
    else
      local exit_code=$?
      register_agent "$agent_id" "$parent_id" "failed"
      failed_agents+=("$agent_id")
      echo "[spawn] Sub-agent $agent_id failed (exit: $exit_code)" >&2
      return $exit_code
    fi
  fi
}

# Spawn all agents in a wave with pre-flight validation
# Args: wave_tasks (JSON array of task objects), parent_id
# Returns: 0 if all succeeded, 1 if any failed
spawn_wave() {
  local wave_tasks_json="$1"
  local parent_id="$2"

  echo "[wave] Starting wave spawn" >&2

  # Parse wave tasks
  local tasks
  readarray -t tasks < <(echo "$wave_tasks_json" | jq -c '.[]' 2>/dev/null)

  if [ ${#tasks[@]} -eq 0 ]; then
    echo "[wave] No tasks in wave" >&2
    return 0
  fi

  echo "[wave] Wave contains ${#tasks[@]} tasks" >&2

  # CRITICAL: Pre-flight scope validation BEFORE spawning any agents
  local wave_id
  wave_id="wave-$(date +%s)"

  if ! validate_wave_scopes "$wave_id" "$wave_tasks_json"; then
    echo "[wave] Wave ABORTED - scope conflicts detected" >&2
    return 1
  fi

  echo "[wave] Pre-flight validation passed - spawning agents" >&2

  # Spawn agents with concurrency limit
  for task in "${tasks[@]}"; do
    # Wait if at concurrency limit
    while [ ${#subagent_pids[@]} -ge $MAX_CONCURRENT ]; do
      echo "[wave] At concurrency limit ($MAX_CONCURRENT), waiting for agent to complete..." >&2
      wait_for_subagent
    done

    # Spawn next agent in background
    if ! spawn_subagent "$parent_id" "$task" true; then
      echo "[wave] Failed to spawn agent for task" >&2
      # Continue with other tasks (let-finish pattern)
    fi
  done

  # Wait for all remaining agents
  echo "[wave] All agents spawned, waiting for completion..." >&2
  while [ ${#subagent_pids[@]} -gt 0 ]; do
    wait_for_subagent
  done

  # Summary
  local completed_count=${#completed_agents[@]}
  local failed_count=${#failed_agents[@]}
  echo "[wave] Wave complete: $completed_count succeeded, $failed_count failed" >&2

  if [ "$failed_count" -gt 0 ]; then
    return 1
  fi

  return 0
}

# Wait for any sub-agent to complete (wait -n pattern from Phase 5)
# Updates completed_agents and failed_agents arrays
# Returns: 0 after processing completion
wait_for_subagent() {
  if [ ${#subagent_pids[@]} -eq 0 ]; then
    return 0
  fi

  # Wait for any background job to complete
  wait -n 2>/dev/null || true

  # Check which agents completed
  for agent_id in "${!subagent_pids[@]}"; do
    local pid="${subagent_pids[$agent_id]}"

    # Check if process still running
    if ! kill -0 "$pid" 2>/dev/null; then
      # Agent finished - check exit status
      wait "$pid" 2>/dev/null
      local exit_code=$?

      if [ $exit_code -eq 0 ]; then
        completed_agents+=("$agent_id")
        echo "[complete] Sub-agent $agent_id finished successfully (PID: $pid)" >&2
      else
        failed_agents+=("$agent_id")
        echo "[failed] Sub-agent $agent_id failed (exit: $exit_code, PID: $pid)" >&2
      fi

      # Remove from tracking
      unset subagent_pids[$agent_id]
    fi
  done
}

# Get status of a specific agent or all agents
# Args: [agent_id] (optional - if omitted, shows all)
# Returns: "running", "complete", "failed", or "unknown"
get_subagent_status() {
  local agent_id="${1:-}"

  if [ -z "$agent_id" ]; then
    # Show all agents
    echo "Sub-agent Status:"
    echo "================="
    echo ""

    echo "Running (${#subagent_pids[@]}):"
    for id in "${!subagent_pids[@]}"; do
      echo "  $id (PID: ${subagent_pids[$id]})"
    done

    echo ""
    echo "Completed (${#completed_agents[@]}):"
    for id in "${completed_agents[@]}"; do
      echo "  $id"
    done

    echo ""
    echo "Failed (${#failed_agents[@]}):"
    for id in "${failed_agents[@]}"; do
      echo "  $id"
    done

    return 0
  fi

  # Check specific agent
  if [ -n "${subagent_pids[$agent_id]:-}" ]; then
    local pid="${subagent_pids[$agent_id]}"
    if kill -0 "$pid" 2>/dev/null; then
      echo "running"
    else
      echo "unknown"
    fi
    return 0
  fi

  # Check completed
  for id in "${completed_agents[@]}"; do
    if [ "$id" = "$agent_id" ]; then
      echo "complete"
      return 0
    fi
  done

  # Check failed
  for id in "${failed_agents[@]}"; do
    if [ "$id" = "$agent_id" ]; then
      echo "failed"
      return 0
    fi
  done

  echo "unknown"
}

# --- CLI Interface ---

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Sub-agent spawner with PID tracking and wave management.

OPTIONS:
  --spawn             Spawn single sub-agent
  --wave              Spawn wave of sub-agents
  --status [ID]       Show status (all agents or specific agent)
  --help              Show this help

SPAWN OPTIONS:
  --parent ID         Parent agent ID (required)
  --task JSON         Task definition JSON (required for --spawn)
  --tasks JSON        Task array JSON (required for --wave)
  --sync              Run synchronously (default: background)
  --max-concurrent N  Maximum concurrent agents (default: 3)

EXAMPLES:
  # Spawn single agent in background
  $(basename "$0") --spawn --parent worker-abc --task '{"id":"t1","name":"Build API","command":"echo test"}'

  # Spawn wave of agents
  $(basename "$0") --wave --parent worker-abc --tasks '[{"id":"t1","name":"Task 1","command":"echo 1"}]'

  # Check status
  $(basename "$0") --status
  $(basename "$0") --status worker-abc/w1-task-xyz

EOF
}

# --- Main ---

main() {
  local mode=""
  local parent_id=""
  local task_json=""
  local tasks_json=""
  local agent_id=""
  local sync=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --spawn)
        mode="spawn"
        shift
        ;;
      --wave)
        mode="wave"
        shift
        ;;
      --status)
        mode="status"
        shift
        if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; then
          agent_id="$1"
          shift
        fi
        ;;
      --parent)
        parent_id="$2"
        shift 2
        ;;
      --task)
        task_json="$2"
        shift 2
        ;;
      --tasks)
        tasks_json="$2"
        shift 2
        ;;
      --sync)
        sync=true
        shift
        ;;
      --max-concurrent)
        MAX_CONCURRENT="$2"
        shift 2
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "[error] Unknown option: $1" >&2
        echo "Use --help for usage" >&2
        exit 1
        ;;
    esac
  done

  # Execute based on mode
  case "$mode" in
    spawn)
      if [ -z "$parent_id" ] || [ -z "$task_json" ]; then
        echo "[error] --spawn requires --parent and --task" >&2
        exit 1
      fi

      local bg="true"
      [ "$sync" = true ] && bg="false"

      spawn_subagent "$parent_id" "$task_json" "$bg"
      ;;
    wave)
      if [ -z "$parent_id" ] || [ -z "$tasks_json" ]; then
        echo "[error] --wave requires --parent and --tasks" >&2
        exit 1
      fi
      spawn_wave "$tasks_json" "$parent_id"
      ;;
    status)
      get_subagent_status "$agent_id"
      ;;
    "")
      echo "[error] No mode specified" >&2
      echo "Use --help for usage" >&2
      exit 1
      ;;
  esac
}

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

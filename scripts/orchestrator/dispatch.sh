#!/usr/bin/env bash
# dispatch.sh - Worker dispatch with dependency-aware parallel execution
#
# Orchestrator uses this to spawn Claude workers for ready issues.
# Supports single dispatch, parallel batches, and full dependency-ordered execution.
#
# Usage:
#   ./dispatch.sh --issue 42              # Dispatch single issue
#   ./dispatch.sh --issues "42 43 44"     # Dispatch multiple (parallel)
#   ./dispatch.sh --all-ready             # Dispatch all ready issues
#   ./dispatch.sh --with-dependencies     # Full dependency-ordered dispatch
#   ./dispatch.sh --max-concurrent 3      # Limit parallel workers (default: 3)
#   ./dispatch.sh --dry-run               # Show what would be dispatched
#   ./dispatch.sh --status                # Show current dispatch state
#
# Dependencies:
#   - scripts/worker/execute.sh (worker entry point)
#   - scripts/orchestrator/graph.sh (dependency functions)
#
# Invoked by:
#   - Gemini orchestrator via skill
#   - Human from command line

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKER_EXECUTE="$REPO_ROOT/scripts/worker/execute.sh"
DISPATCH_DIR="$REPO_ROOT/.worker/dispatch"
DISPATCH_LOG="$DISPATCH_DIR/dispatch.jsonl"
DISPATCH_STATE="$DISPATCH_DIR/state.json"

# Default settings
MAX_CONCURRENT=3
DRY_RUN=false
VERBOSE=false

# --- Source dependencies ---
source "$SCRIPT_DIR/graph.sh"

# --- Tracking ---
# Associative array: issue -> PID
declare -A worker_pids=()
# Array of completed issues this session
declare -a completed_issues=()
# Array of failed issues this session
declare -a failed_issues=()

# --- Helper Functions ---

# Ensure dispatch directory exists
init_dispatch() {
  mkdir -p "$DISPATCH_DIR"
  mkdir -p "$REPO_ROOT/.worker/logs"
}

# Log dispatch event in JSON format (consistent with worker logger)
log_dispatch() {
  local event_type="$1"
  shift

  # Collect --arg pairs
  local -a arg_flags=()
  local -a arg_names=()

  while [ $# -gt 0 ]; do
    if [ "$1" = "--arg" ]; then
      arg_flags+=("--arg" "$2" "$3")
      arg_names+=("$2")
      shift 3
    else
      shift
    fi
  done

  # Build jq expression for data object
  local jq_expr='{'
  local first=true
  for name in "${arg_names[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      jq_expr+=', '
    fi
    jq_expr+="$name: \$$name"
  done
  jq_expr+='}'

  # Build data object
  local data_json
  if [ ${#arg_flags[@]} -gt 0 ]; then
    data_json=$(jq -n "${arg_flags[@]}" "$jq_expr")
  else
    data_json='{}'
  fi

  # Emit structured event
  jq -nc \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg event_type "$event_type" \
    --arg event_id "dispatch-$(date +%s%N)-$$" \
    --argjson data "$data_json" \
    '{
      timestamp: $timestamp,
      event_type: $event_type,
      event_id: $event_id,
      data: $data
    }' >> "$DISPATCH_LOG"
}

# Output message (respects verbose mode)
msg() {
  local level="$1"
  shift
  echo "[$level] $*"
}

# Verbose output (only if --verbose)
verbose() {
  if [ "$VERBOSE" = true ]; then
    msg "debug" "$@"
  fi
}

# --- Core Dispatch Functions ---

# Dispatch a single worker for one issue
# Arguments: issue_number [background]
# Returns: 0 on success, 1 on error
dispatch_single() {
  local issue="$1"
  local background="${2:-false}"

  if [ -z "$issue" ]; then
    msg "error" "Issue number required"
    return 1
  fi

  if [ "$DRY_RUN" = true ]; then
    msg "dry-run" "Would dispatch worker for issue #$issue"
    return 0
  fi

  # Check worker execute script exists
  if [ ! -x "$WORKER_EXECUTE" ]; then
    msg "error" "Worker execute script not found or not executable: $WORKER_EXECUTE"
    return 1
  fi

  # Log dispatch start
  log_dispatch "dispatch_start" \
    --arg issue "$issue" \
    --arg background "$background"

  if [ "$background" = true ]; then
    # Run in background and track PID
    "$WORKER_EXECUTE" --issue "$issue" &
    local pid=$!
    worker_pids[$issue]=$pid
    msg "dispatch" "Started worker for #$issue (PID: $pid)"
    verbose "Background dispatch: issue=$issue pid=$pid"
  else
    # Run synchronously
    msg "dispatch" "Executing worker for #$issue (synchronous)"
    if "$WORKER_EXECUTE" --issue "$issue"; then
      completed_issues+=("$issue")
      log_dispatch "dispatch_complete" \
        --arg issue "$issue" \
        --arg exit_code "0"
      msg "complete" "Worker for #$issue finished successfully"
      return 0
    else
      local exit_code=$?
      failed_issues+=("$issue")
      log_dispatch "dispatch_failed" \
        --arg issue "$issue" \
        --arg exit_code "$exit_code"
      msg "failed" "Worker for #$issue failed (exit: $exit_code)"
      return $exit_code
    fi
  fi
}

# Wait for any one worker to complete
# Uses bash 4.3+ wait -n feature
# Returns: 0 if a worker completed, updates tracking arrays
wait_for_worker() {
  if [ ${#worker_pids[@]} -eq 0 ]; then
    return 0
  fi

  # Wait for any background job to complete
  wait -n 2>/dev/null || true

  # Check which workers completed
  local -a still_running=()
  for issue in "${!worker_pids[@]}"; do
    local pid="${worker_pids[$issue]}"
    if kill -0 "$pid" 2>/dev/null; then
      still_running+=("$issue")
    else
      # Worker completed, check exit status
      wait "$pid" 2>/dev/null
      local exit_code=$?

      if [ $exit_code -eq 0 ]; then
        completed_issues+=("$issue")
        log_dispatch "dispatch_complete" \
          --arg issue "$issue" \
          --arg exit_code "0" \
          --arg pid "$pid"
        msg "complete" "Worker for #$issue finished successfully (PID: $pid)"
      else
        failed_issues+=("$issue")
        log_dispatch "dispatch_failed" \
          --arg issue "$issue" \
          --arg exit_code "$exit_code" \
          --arg pid "$pid"
        msg "failed" "Worker for #$issue failed (exit: $exit_code, PID: $pid)"
      fi

      # Remove from tracking
      unset worker_pids[$issue]
    fi
  done
}

# Dispatch multiple issues in parallel with concurrency limit
# Arguments: issue_list (space-separated)
dispatch_parallel() {
  local issues="$1"

  if [ -z "$issues" ]; then
    msg "info" "No issues to dispatch"
    return 0
  fi

  msg "info" "Dispatching issues: $issues (max concurrent: $MAX_CONCURRENT)"

  if [ "$DRY_RUN" = true ]; then
    for issue in $issues; do
      msg "dry-run" "Would dispatch worker for issue #$issue"
    done
    return 0
  fi

  for issue in $issues; do
    # Wait if at max concurrent limit
    while [ ${#worker_pids[@]} -ge $MAX_CONCURRENT ]; do
      verbose "At concurrency limit ($MAX_CONCURRENT), waiting for worker..."
      wait_for_worker
    done

    # Dispatch in background
    dispatch_single "$issue" true
  done

  # Wait for all remaining workers
  msg "info" "Waiting for ${#worker_pids[@]} remaining workers..."
  while [ ${#worker_pids[@]} -gt 0 ]; do
    wait_for_worker
  done

  # Summary
  msg "info" "Dispatch complete: ${#completed_issues[@]} succeeded, ${#failed_issues[@]} failed"
}

# Full dependency-aware dispatch
# Dispatches in waves based on topological order
dispatch_with_dependencies() {
  msg "info" "Starting dependency-aware dispatch"

  # Get ready issues (no unresolved dependencies)
  local ready
  ready=$(get_ready_issues)

  if [ -z "$ready" ]; then
    msg "info" "No issues ready for dispatch"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    msg "dry-run" "Execution order based on dependencies:"
    local order
    order=$(get_execution_order)
    local wave=1
    for issue in $order; do
      if echo "$ready" | grep -qw "$issue"; then
        msg "dry-run" "  Wave $wave: Issue #$issue (ready)"
      else
        msg "dry-run" "  Wave ?: Issue #$issue (blocked)"
      fi
    done
    return 0
  fi

  # Dispatch in waves: only dispatch issues whose dependencies are complete
  local wave=1
  while true; do
    # Get currently ready issues
    ready=$(get_ready_issues)

    if [ -z "$ready" ]; then
      # Check if there are still open issues (blocked)
      local remaining
      remaining=$(gh issue list --state open --json number --jq '.[].number' 2>/dev/null | wc -l)
      if [ "$remaining" -gt 0 ]; then
        msg "warning" "No ready issues but $remaining issues still open (may be blocked by failures)"
      fi
      break
    fi

    msg "info" "Wave $wave: dispatching $(echo "$ready" | wc -w | tr -d ' ') ready issues"

    # Filter out already completed or failed issues
    local to_dispatch=""
    for issue in $ready; do
      # Skip if already processed
      if printf '%s\n' "${completed_issues[@]}" 2>/dev/null | grep -qw "$issue"; then
        continue
      fi
      if printf '%s\n' "${failed_issues[@]}" 2>/dev/null | grep -qw "$issue"; then
        continue
      fi
      to_dispatch="$to_dispatch $issue"
    done

    to_dispatch=$(echo "$to_dispatch" | xargs)
    if [ -z "$to_dispatch" ]; then
      break
    fi

    # Dispatch this wave
    dispatch_parallel "$to_dispatch"

    # Handle failures - detect cascade
    for failed in "${failed_issues[@]}"; do
      local cascade
      cascade=$(detect_cascade "$failed")
      if [ -n "$cascade" ]; then
        msg "warning" "Issue #$failed failure blocks: $cascade"
        # Could add blocked label here via gh issue edit
      fi
    done

    ((wave++))

    # Safety limit
    if [ $wave -gt 100 ]; then
      msg "error" "Too many waves (>100), possible infinite loop"
      return 1
    fi
  done

  msg "info" "Dependency-aware dispatch complete after $((wave-1)) waves"
  msg "info" "Total: ${#completed_issues[@]} succeeded, ${#failed_issues[@]} failed"
}

# Handle worker completion callback
# Called after a worker finishes to potentially unblock dependents
on_worker_complete() {
  local issue="$1"
  local exit_code="$2"

  if [ "$exit_code" -eq 0 ]; then
    verbose "Worker for #$issue completed successfully"
    # Dependents may now be ready - will be picked up in next dispatch wave
  else
    msg "warning" "Worker for #$issue failed"

    # Detect cascade of blocked issues
    local cascade
    cascade=$(detect_cascade "$issue")
    if [ -n "$cascade" ]; then
      msg "warning" "Cascade: Issues blocked by #$issue failure: $cascade"
      # Label blocked issues for visibility
      for blocked in $cascade; do
        verbose "Labeling #$blocked as cascade-blocked"
        gh issue edit "$blocked" --add-label "blocked" 2>/dev/null || true
      done
    fi
  fi
}

# --- Status and Monitoring ---

# Get current dispatch status
# Queries running workers, GitHub labels, and provides summary
get_dispatch_status() {
  echo "Dispatch Status"
  echo "==============="
  echo ""

  # Check running workers (from PIDs)
  local running_count=0
  local running_list=""
  for issue in "${!worker_pids[@]}"; do
    local pid="${worker_pids[$issue]}"
    if kill -0 "$pid" 2>/dev/null; then
      running_list="$running_list #$issue (PID $pid),"
      ((running_count++))
    fi
  done
  if [ $running_count -gt 0 ]; then
    running_list="${running_list%,}"  # Remove trailing comma
    echo "Running: $running_list"
  else
    echo "Running: none"
  fi

  # Query GitHub for worker states
  echo ""

  # Issues with worker:planning label (awaiting approval)
  local awaiting
  awaiting=$(gh issue list --label "worker:awaiting-approval" --json number --jq '.[].number' 2>/dev/null | tr '\n' ' ' | xargs)
  if [ -n "$awaiting" ]; then
    echo "Awaiting approval: $(echo "$awaiting" | sed 's/ /, #/g; s/^/#/')"
  else
    echo "Awaiting approval: none"
  fi

  # Issues with worker:executing label
  local executing
  executing=$(gh issue list --label "worker:executing" --json number --jq '.[].number' 2>/dev/null | tr '\n' ' ' | xargs)
  if [ -n "$executing" ]; then
    echo "Executing: $(echo "$executing" | sed 's/ /, #/g; s/^/#/')"
  else
    echo "Executing: none"
  fi

  # Issues with worker:complete label
  local complete
  complete=$(gh issue list --label "worker:complete" --state all --json number --jq '.[].number' 2>/dev/null | tr '\n' ' ' | xargs)
  if [ -n "$complete" ]; then
    echo "Complete: $(echo "$complete" | sed 's/ /, #/g; s/^/#/')"
  else
    echo "Complete: none"
  fi

  # Issues with worker:failed label
  local failed
  failed=$(gh issue list --label "worker:failed" --json number --jq '.[].number' 2>/dev/null | tr '\n' ' ' | xargs)
  if [ -n "$failed" ]; then
    echo "Failed: $(echo "$failed" | sed 's/ /, #/g; s/^/#/')"
  else
    echo "Failed: none"
  fi

  echo ""

  # Next ready issues
  local ready
  ready=$(get_ready_issues 2>/dev/null | tr '\n' ' ' | xargs)
  if [ -n "$ready" ]; then
    echo "Next ready: $(echo "$ready" | sed 's/ /, #/g; s/^/#/')"
  else
    echo "Next ready: none"
  fi

  # Session summary (if any activity)
  local completed_count=${#completed_issues[@]}
  local failed_count=${#failed_issues[@]}
  if [ "$completed_count" -gt 0 ] || [ "$failed_count" -gt 0 ]; then
    echo ""
    echo "This session:"
    echo "  Completed: $completed_count"
    echo "  Failed: $failed_count"
  fi
}

# Cleanup handler for graceful shutdown
cleanup_dispatch() {
  local exit_code=$?

  # Get array sizes safely (handle uninitialized)
  local completed_count=${#completed_issues[@]}
  local failed_count=${#failed_issues[@]}
  local running_count=${#worker_pids[@]}

  # Log session end
  if [ -f "$DISPATCH_LOG" ] 2>/dev/null; then
    log_dispatch "dispatch_session_end" \
      --arg completed "$completed_count" \
      --arg failed "$failed_count" \
      --arg running "$running_count" \
      --arg exit_code "$exit_code"
  fi

  # If there are still running workers, warn but don't kill by default
  if [ "$running_count" -gt 0 ] 2>/dev/null; then
    msg "warning" "$running_count workers still running"
    for issue in "${!worker_pids[@]}"; do
      msg "warning" "  #$issue (PID ${worker_pids[$issue]})"
    done
    msg "info" "Workers will continue in background. Use --force to kill on abort."
  fi
}

# Force kill all running workers
kill_workers() {
  local count=${#worker_pids[@]}
  msg "info" "Killing $count running workers..."
  for issue in "${!worker_pids[@]}"; do
    local pid="${worker_pids[$issue]}"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      msg "killed" "Worker for #$issue (PID $pid)"
    fi
  done
  worker_pids=()
}

# --- CLI Interface ---

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Worker dispatch with dependency-aware parallel execution.

OPTIONS:
  --issue N            Dispatch single issue
  --issues "N M O"     Dispatch multiple issues (parallel)
  --all-ready          Dispatch all ready issues (no blockers)
  --with-dependencies  Full dependency-ordered dispatch (waves)
  --max-concurrent N   Maximum concurrent workers (default: 3)
  --dry-run            Show what would be dispatched without executing
  --status             Show current dispatch state
  --verbose            Enable verbose output
  --force              Kill workers on abort (use with Ctrl+C)
  --help               Show this help message

EXAMPLES:
  # Dispatch single issue
  $(basename "$0") --issue 42

  # Dispatch multiple issues in parallel
  $(basename "$0") --issues "42 43 44" --max-concurrent 2

  # Dispatch all ready issues
  $(basename "$0") --all-ready

  # Full dependency-aware dispatch
  $(basename "$0") --with-dependencies

  # Dry run to see plan
  $(basename "$0") --all-ready --dry-run

  # Check current status
  $(basename "$0") --status

DISPATCH MODES:
  Single:     Runs one worker, waits for completion
  Parallel:   Runs multiple workers with concurrency limit
  Dependency: Runs in waves, respecting "Blocked by #N" patterns

WORKER STATES (GitHub labels):
  worker:planning          Plan posted, awaiting approval
  worker:awaiting-approval Explicit approval gate
  worker:executing         Currently running
  worker:complete          Successfully finished
  worker:failed            Execution failed

EOF
}

# --- Main ---

main() {
  local mode=""
  local issue=""
  local issues=""
  local force=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --issue)
        mode="single"
        issue="$2"
        shift 2
        ;;
      --issues)
        mode="parallel"
        issues="$2"
        shift 2
        ;;
      --all-ready)
        mode="ready"
        shift
        ;;
      --with-dependencies)
        mode="dependencies"
        shift
        ;;
      --max-concurrent)
        MAX_CONCURRENT="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --status)
        mode="status"
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --force)
        force=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        msg "error" "Unknown option: $1"
        echo "Use --help for usage"
        exit 1
        ;;
    esac
  done

  # Initialize dispatch infrastructure
  init_dispatch

  # Set up cleanup trap
  if [ "$force" = true ]; then
    trap 'kill_workers; cleanup_dispatch' EXIT
  else
    trap cleanup_dispatch EXIT
  fi

  # Execute based on mode
  case "$mode" in
    single)
      if [ -z "$issue" ]; then
        msg "error" "--issue requires an issue number"
        exit 1
      fi
      dispatch_single "$issue" false
      ;;
    parallel)
      if [ -z "$issues" ]; then
        msg "error" "--issues requires a list of issue numbers"
        exit 1
      fi
      dispatch_parallel "$issues"
      ;;
    ready)
      local ready_issues
      ready_issues=$(get_ready_issues | tr '\n' ' ')
      if [ -z "$ready_issues" ] || [ "$ready_issues" = " " ]; then
        msg "info" "No issues ready for dispatch"
        exit 0
      fi
      dispatch_parallel "$ready_issues"
      ;;
    dependencies)
      dispatch_with_dependencies
      ;;
    status)
      get_dispatch_status
      ;;
    "")
      msg "error" "No dispatch mode specified"
      echo "Use --help for usage"
      exit 1
      ;;
  esac
}

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

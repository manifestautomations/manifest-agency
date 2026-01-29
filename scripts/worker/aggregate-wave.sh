#!/usr/bin/env bash
# aggregate-wave.sh - Wave result aggregation and commit management
#
# Collects results from parallel sub-agents, verifies outputs, and creates
# unified wave commits. Handles rollback and salvage operations on failure.
#
# Usage:
#   ./aggregate-wave.sh --aggregate wave-123456
#   ./aggregate-wave.sh --rollback wave-123456
#   ./aggregate-wave.sh --verify wave-123456
#
# Functions (when sourced):
#   aggregate_wave_results wave_id
#     - Collect and verify results from completed sub-agents
#   verify_wave_outputs wave_id completed_agents
#     - Structural and syntactic verification of outputs
#   create_wave_commit wave_num completed_agents
#     - Create unified commit for wave results
#   rollback_wave wave_id
#     - Unstage and restore to pre-wave state
#   handle_wave_failure wave_id failed_agent
#     - Let-finish with salvage decision logic
#
# Dependencies:
#   - jq (JSON processing)
#   - git (version control)
#   - yq (YAML processing, optional for verification)

# Include guard - prevent multiple sourcing
[[ -n "${_AGGREGATE_WAVE_SOURCED:-}" ]] && return 0
_AGGREGATE_WAVE_SOURCED=1

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKER_DIR="$REPO_ROOT/.worker"

# --- Aggregation Functions ---

# Aggregate results from completed sub-agents
# Args: wave_id
# Returns: 0 if all outputs present and valid, 1 if missing/invalid
aggregate_wave_results() {
  local wave_id="$1"
  local wave_dir="$WORKER_DIR/waves/$wave_id"

  echo "[aggregate] Collecting results from wave $wave_id" >&2

  # Check wave directory exists
  if [ ! -d "$wave_dir" ]; then
    echo "[error] Wave directory not found: $wave_dir" >&2
    return 1
  fi

  # Load agents.json
  if [ ! -f "$wave_dir/agents.json" ]; then
    echo "[error] agents.json not found in wave directory" >&2
    return 1
  fi

  # Get list of completed agents
  local completed_agents
  completed_agents=$(jq -r '.agents[]? | select(.status == "complete") | .id' "$wave_dir/agents.json" 2>/dev/null || echo "")

  if [ -z "$completed_agents" ]; then
    echo "[warning] No completed agents in wave" >&2
    return 1
  fi

  local completed_count
  completed_count=$(echo "$completed_agents" | wc -l | tr -d ' ')
  echo "[aggregate] Found $completed_count completed agents" >&2

  # Verify wave outputs
  if ! verify_wave_outputs "$wave_id" "$completed_agents"; then
    echo "[aggregate] Verification failed" >&2
    return 1
  fi

  # Stage all files in each agent's write_scope
  echo "[aggregate] Staging changes..." >&2

  while IFS= read -r agent_id; do
    echo "[aggregate] Staging files from: $agent_id" >&2

    # Get write_scope for this agent
    local write_scope
    write_scope=$(jq -r ".agents[]? | select(.id == \"$agent_id\") | .write_scope[]?" "$wave_dir/agents.json" 2>/dev/null || echo "")

    if [ -z "$write_scope" ]; then
      echo "[warning] No write_scope found for $agent_id" >&2
      continue
    fi

    # Stage each file in write scope
    while IFS= read -r file; do
      if [ -n "$file" ] && [ -f "$file" ]; then
        git add "$file" 2>/dev/null || echo "[warning] Could not stage: $file" >&2
      else
        echo "[warning] Expected file not found: $file" >&2
      fi
    done <<< "$write_scope"
  done <<< "$completed_agents"

  echo "[aggregate] ✓ Aggregation complete" >&2
  return 0
}

# Verify wave outputs (structural and syntactic)
# Args: wave_id, completed_agents (newline-separated agent IDs)
# Returns: 0 if valid, 1 if issues found
verify_wave_outputs() {
  local wave_id="$1"
  local completed_agents="$2"
  local wave_dir="$WORKER_DIR/waves/$wave_id"

  echo "[verify] Starting verification pipeline" >&2

  local verification_failed=false

  # Per CONTEXT.md verification pipeline:
  # 1. Structural - All expected outputs present
  # 2. Syntactic - Code parses successfully

  while IFS= read -r agent_id; do
    echo "[verify] Checking agent: $agent_id" >&2

    # Get expected outputs from agents.json
    local expected_outputs
    expected_outputs=$(jq -r ".agents[]? | select(.id == \"$agent_id\") | .expected_outputs[]?" "$wave_dir/agents.json" 2>/dev/null || echo "")

    if [ -z "$expected_outputs" ]; then
      echo "[info] No expected outputs defined for $agent_id, skipping" >&2
      continue
    fi

    # Structural verification: Check all expected outputs exist
    while IFS= read -r output_file; do
      if [ -n "$output_file" ]; then
        if [ ! -f "$output_file" ]; then
          echo "[error] Missing expected output: $output_file from $agent_id" >&2
          verification_failed=true
        else
          echo "[verify] ✓ Found: $output_file" >&2

          # Syntactic verification: Check if code parses
          if ! verify_file_syntax "$output_file"; then
            echo "[error] Syntax validation failed: $output_file" >&2
            verification_failed=true
          fi
        fi
      fi
    done <<< "$expected_outputs"
  done <<< "$completed_agents"

  if [ "$verification_failed" = true ]; then
    echo "[verify] ✗ Verification failed" >&2
    return 1
  fi

  echo "[verify] ✓ All outputs verified" >&2
  return 0
}

# Verify file syntax based on extension
# Args: file_path
# Returns: 0 if parses, 1 if syntax error
verify_file_syntax() {
  local file="$1"

  # Skip verification for non-code files
  case "$file" in
    *.sh)
      # Bash syntax check
      if command -v bash &> /dev/null; then
        bash -n "$file" 2>/dev/null || {
          echo "[syntax] Bash syntax error in: $file" >&2
          return 1
        }
      fi
      ;;
    *.js|*.jsx)
      # Node.js syntax check (if available)
      if command -v node &> /dev/null; then
        node --check "$file" 2>/dev/null || {
          echo "[syntax] JavaScript syntax error in: $file" >&2
          return 1
        }
      fi
      ;;
    *.ts|*.tsx)
      # TypeScript syntax check (if available)
      if command -v tsc &> /dev/null; then
        tsc --noEmit "$file" 2>/dev/null || {
          echo "[syntax] TypeScript syntax error in: $file" >&2
          return 1
        }
      fi
      ;;
    *.py)
      # Python syntax check (if available)
      if command -v python3 &> /dev/null; then
        python3 -m py_compile "$file" 2>/dev/null || {
          echo "[syntax] Python syntax error in: $file" >&2
          return 1
        }
      fi
      ;;
    *.json)
      # JSON validation
      if command -v jq &> /dev/null; then
        jq empty "$file" 2>/dev/null || {
          echo "[syntax] JSON syntax error in: $file" >&2
          return 1
        }
      fi
      ;;
    *.yaml|*.yml)
      # YAML validation (if yq available)
      if command -v yq &> /dev/null; then
        yq eval '.' "$file" >/dev/null 2>&1 || {
          echo "[syntax] YAML syntax error in: $file" >&2
          return 1
        }
      fi
      ;;
    *)
      # Unknown file type - skip syntax check
      echo "[verify] Skipping syntax check for: $file" >&2
      ;;
  esac

  return 0
}

# Create unified wave commit
# Args: wave_num, completed_agents (newline-separated agent IDs)
# Returns: 0 on success, 1 on failure
create_wave_commit() {
  local wave_num="$1"
  local completed_agents="$2"

  echo "[commit] Creating wave commit for wave $wave_num" >&2

  # Check if there are staged changes
  if git diff --cached --quiet; then
    echo "[warning] No staged changes to commit" >&2
    return 1
  fi

  # Build commit message per CONTEXT.md format
  # Format:
  # feat({scope}): {summary}
  #
  # Wave {N} parallel execution:
  # - [{agent-slug}] {summary}
  # - [{agent-slug}] {summary}
  #
  # Phase: {phase} | Wave: {wave} | Duration: {duration}
  # Worker: {worker_id}

  # Extract phase and scope from environment or default
  local phase="${PHASE:-unknown}"
  local scope="${SCOPE:-worker}"
  local worker_id="${WORKER_ID:-claude-worker}"

  # Calculate duration
  local wave_dir="$WORKER_DIR/waves/wave-$wave_num"
  local duration="unknown"
  if [ -f "$wave_dir/start.timestamp" ] && [ -f "$wave_dir/end.timestamp" ]; then
    local start_time end_time
    start_time=$(cat "$wave_dir/start.timestamp")
    end_time=$(cat "$wave_dir/end.timestamp")
    local duration_sec=$((end_time - start_time))
    local duration_min=$((duration_sec / 60))
    local duration_rem=$((duration_sec % 60))
    duration="${duration_min}m ${duration_rem}s"
  fi

  # Build agent summaries
  local agent_summaries=""
  local completed_count=0

  while IFS= read -r agent_id; do
    if [ -z "$agent_id" ]; then
      continue
    fi

    # Extract agent slug (task name part from agent ID)
    # Format: parent/w{wave}-{task-slug}-{hash}
    local agent_slug
    agent_slug=$(echo "$agent_id" | grep -oE 'w[0-9]+-[^-]+' | sed 's/w[0-9]*-//' || echo "task")

    # Get agent summary from agents.json
    local agent_summary
    agent_summary=$(jq -r ".agents[]? | select(.id == \"$agent_id\") | .task_summary // .name // \"Unknown\"" \
      "$wave_dir/agents.json" 2>/dev/null || echo "Completed task")

    agent_summaries+="- [${agent_slug}] ${agent_summary}
"
    completed_count=$((completed_count + 1))
  done <<< "$completed_agents"

  # Construct commit message using heredoc
  local commit_message
  commit_message=$(cat <<EOF
feat(${scope}): wave ${wave_num} parallel execution

Wave ${wave_num} parallel execution:
${agent_summaries}
Phase: ${phase} | Wave: ${wave_num} | Duration: ${duration}
Worker: ${worker_id}
EOF
)

  # Create commit
  echo "[commit] Committing with message:" >&2
  echo "$commit_message" | head -3 >&2
  echo "..." >&2

  if git commit -m "$commit_message" 2>&1; then
    local commit_hash
    commit_hash=$(git rev-parse --short HEAD)
    echo "[commit] ✓ Wave commit created: $commit_hash" >&2
    return 0
  else
    echo "[commit] ✗ Failed to create commit" >&2
    return 1
  fi
}

# Rollback wave - unstage and restore to pre-wave state
# Args: wave_id
# Returns: 0 on success
rollback_wave() {
  local wave_id="$1"

  echo "[rollback] Rolling back wave $wave_id" >&2

  # Get list of staged files
  local staged_files
  staged_files=$(git diff --cached --name-only 2>/dev/null || echo "")

  if [ -z "$staged_files" ]; then
    echo "[rollback] No staged files to rollback" >&2
    return 0
  fi

  echo "[rollback] Unstaging files..." >&2

  # Unstage all files
  # shellcheck disable=SC2086
  git reset HEAD $staged_files 2>&1 || echo "[warning] Some files could not be unstaged" >&2

  # Restore to pre-wave state
  echo "[rollback] Restoring files to pre-wave state..." >&2
  # shellcheck disable=SC2086
  git checkout -- $staged_files 2>&1 || echo "[warning] Some files could not be restored" >&2

  echo "[rollback] ✓ Wave rolled back - no history pollution" >&2

  return 0
}

# Handle wave failure with let-finish and salvage decision
# Args: wave_id, failed_agent
# Returns: 0 if salvaged/retried, 1 if complete rollback
handle_wave_failure() {
  local wave_id="$1"
  local failed_agent="$2"

  echo "[failure] Agent $failed_agent failed - assessing wave state" >&2

  # Per CONTEXT.md: Let running agents complete (no cancellation)
  echo "[salvage] Allowing running agents to complete (let-finish pattern)..." >&2

  # NOTE: This function is called AFTER wait completes in spawn_wave
  # So all agents have already finished at this point

  local wave_dir="$WORKER_DIR/waves/$wave_id"

  # Get completed and failed counts
  local completed_agents failed_agents
  completed_agents=$(jq -r '.agents[]? | select(.status == "complete") | .id' "$wave_dir/agents.json" 2>/dev/null || echo "")
  failed_agents=$(jq -r '.agents[]? | select(.status == "failed") | .id' "$wave_dir/agents.json" 2>/dev/null || echo "")

  local completed_count failed_count
  completed_count=$(echo "$completed_agents" | grep -c . || echo "0")
  failed_count=$(echo "$failed_agents" | grep -c . || echo "0")

  echo "[salvage] Wave results: $completed_count succeeded, $failed_count failed" >&2

  # Check if succeeded work is independent (salvageable)
  # For now, simple heuristic: if any completed, attempt salvage
  local salvageable=true

  if [ "$completed_count" -eq 0 ]; then
    echo "[salvage] No completed work to salvage" >&2
    salvageable=false
  fi

  # Decision: salvage partial or rollback entire wave
  if [ "$salvageable" = true ]; then
    echo "[salvage] Keeping $completed_count completed tasks" >&2

    # Aggregate partial wave (only completed agents)
    if verify_wave_outputs "$wave_id" "$completed_agents"; then
      # Stage completed work
      aggregate_wave_results "$wave_id"

      echo "[salvage] ✓ Partial work salvaged - ready for retry of failed tasks" >&2
      echo "[salvage] Failed agents: $failed_count" >&2
      while IFS= read -r failed_id; do
        echo "  - $failed_id" >&2
      done <<< "$failed_agents"

      return 0
    else
      echo "[salvage] Verification failed for completed work - must rollback" >&2
      salvageable=false
    fi
  fi

  if [ "$salvageable" = false ]; then
    echo "[salvage] Rolling back entire wave - dependencies broken or no salvageable work" >&2
    rollback_wave "$wave_id"
    return 1
  fi
}

# --- CLI Interface ---

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Wave result aggregation and commit management.

OPTIONS:
  --aggregate WAVE_ID     Aggregate results and create commit
  --rollback WAVE_ID      Rollback wave (unstage and restore)
  --verify WAVE_ID        Verify outputs only (no commit)
  --help                  Show this help

EXAMPLES:
  # Aggregate and commit wave results
  $(basename "$0") --aggregate wave-1234567890

  # Verify outputs without committing
  $(basename "$0") --verify wave-1234567890

  # Rollback failed wave
  $(basename "$0") --rollback wave-1234567890

EOF
}

# --- Main ---

main() {
  local mode=""
  local wave_id=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --aggregate)
        mode="aggregate"
        wave_id="$2"
        shift 2
        ;;
      --rollback)
        mode="rollback"
        wave_id="$2"
        shift 2
        ;;
      --verify)
        mode="verify"
        wave_id="$2"
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

  # Validate wave_id provided
  if [ -z "$wave_id" ]; then
    echo "[error] Wave ID required" >&2
    show_help
    exit 1
  fi

  # Execute based on mode
  case "$mode" in
    aggregate)
      # Aggregate and commit
      if aggregate_wave_results "$wave_id"; then
        # Extract wave number from wave_id
        local wave_num
        wave_num=$(echo "$wave_id" | grep -oE '[0-9]+' | head -1 || echo "unknown")

        # Get completed agents
        local wave_dir="$WORKER_DIR/waves/$wave_id"
        local completed_agents
        completed_agents=$(jq -r '.agents[]? | select(.status == "complete") | .id' "$wave_dir/agents.json" 2>/dev/null || echo "")

        if [ -n "$completed_agents" ]; then
          create_wave_commit "$wave_num" "$completed_agents"
        else
          echo "[error] No completed agents to commit" >&2
          exit 1
        fi
      else
        exit 1
      fi
      ;;
    rollback)
      rollback_wave "$wave_id"
      ;;
    verify)
      # Verify only
      local wave_dir="$WORKER_DIR/waves/$wave_id"
      local completed_agents
      completed_agents=$(jq -r '.agents[]? | select(.status == "complete") | .id' "$wave_dir/agents.json" 2>/dev/null || echo "")

      if [ -z "$completed_agents" ]; then
        echo "[error] No completed agents to verify" >&2
        exit 1
      fi

      verify_wave_outputs "$wave_id" "$completed_agents"
      ;;
    "")
      echo "[error] No mode specified" >&2
      show_help
      exit 1
      ;;
  esac
}

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

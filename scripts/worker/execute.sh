#!/usr/bin/env bash
#
# Worker Execute Script
# Orchestrates GitHub issue -> work -> PR lifecycle
#
# Usage:
#   ./scripts/worker/execute.sh --issue 42
#   ./scripts/worker/execute.sh --issue 42 --force    # Override stale lock
#   ./scripts/worker/execute.sh --issue 42 --status   # Show status only
#
# Invokable by:
#   - Human from command line
#   - Orchestrator (Phase 5) via subprocess
#

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKER_DIR="$REPO_ROOT/.worker"
LIB_DIR="$REPO_ROOT/.claude/skills/worker/lib"
SCRIPTS_DIR="$REPO_ROOT/scripts"
# Save original SCRIPT_DIR before sourcing libs that may overwrite it
WORKER_SCRIPT_DIR="$SCRIPT_DIR"

# --- Source libraries ---
# Phase 3/4 core libs (may overwrite SCRIPT_DIR)
source "$LIB_DIR/logger.sh"
source "$LIB_DIR/lock.sh"
source "$LIB_DIR/parser.sh"
source "$LIB_DIR/audit.sh"
source "$LIB_DIR/validator.sh"
source "$LIB_DIR/hooks.sh"
# Phase 6 parallelization libs (use saved path)
source "$WORKER_SCRIPT_DIR/lib/graph-parser.sh"
source "$WORKER_SCRIPT_DIR/spawn-subagent.sh"
source "$WORKER_SCRIPT_DIR/aggregate-wave.sh"

# --- Parse arguments ---
ISSUE_NUMBER=""
FORCE_LOCK=false
STATUS_ONLY=false
FORCE_SERIAL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --issue)
      ISSUE_NUMBER="$2"
      shift 2
      ;;
    --force)
      FORCE_LOCK=true
      shift
      ;;
    --status)
      STATUS_ONLY=true
      shift
      ;;
    --serial)
      FORCE_SERIAL=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 --issue N [--force] [--status] [--serial]"
      echo ""
      echo "Execute work from a GitHub issue in an isolated worktree."
      echo ""
      echo "Options:"
      echo "  --issue N   Issue number to execute (required)"
      echo "  --force     Override stale lock (use after crash)"
      echo "  --status    Show execution status from logs"
      echo "  --serial    Force serial execution (bypass parallelization)"
      echo "  --help      Show this help message"
      echo ""
      echo "Workflow:"
      echo "  1. First run: Posts execution plan, exits awaiting approval"
      echo "  2. Human reviews plan, reacts with thumbs-up"
      echo "  3. Second run: Detects approval, executes work, creates PR"
      exit 0
      ;;
    *)
      echo "[error] Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$ISSUE_NUMBER" ]; then
  echo "[error] --issue is required"
  echo "Usage: $0 --issue N"
  exit 1
fi

# --- Status mode ---
if [ "$STATUS_ONLY" = true ]; then
  echo "[worker] Status for issue #${ISSUE_NUMBER}"
  echo ""

  # Check lock status
  check_lock_status "$ISSUE_NUMBER" 2>/dev/null || true
  echo ""

  # Find latest log file
  LOG_PATTERN="$WORKER_DIR/logs/issue-${ISSUE_NUMBER}-*.jsonl"
  LATEST_LOG=$(ls -t $LOG_PATTERN 2>/dev/null | head -1 || echo "")

  if [ -n "$LATEST_LOG" ]; then
    echo "Latest log: $LATEST_LOG"
    echo ""
    echo "Recent events:"
    tail -5 "$LATEST_LOG" | jq -r '"  [\(.event_type)] \(.data | tostring)"' 2>/dev/null || cat "$LATEST_LOG" | tail -5
  else
    echo "No log files found for issue #${ISSUE_NUMBER}"
  fi

  exit 0
fi

# --- Main execution ---
echo "[worker] Starting execution for issue #${ISSUE_NUMBER}"
echo ""

# Initialize logging
init_logging "$ISSUE_NUMBER"
log_event "worker_start" --arg issue "$ISSUE_NUMBER" --arg force "$FORCE_LOCK"

# Initialize audit chain
init_audit_chain

# Load guardrail configuration
GUARDRAILS_ENABLED=$(jq -r '.guardrails.enabled // true' "$WORKER_DIR/config.json")
DEFAULT_TRUST_LEVEL=$(jq -r '.guardrails.default_trust_level // 2' "$WORKER_DIR/config.json")
AGENT_NAME="${AGENT_NAME:-claude-worker}"

# Audit: Log worker start
log_audit_event "worker_start" \
  --arg agent "$AGENT_NAME" \
  --arg issue "$ISSUE_NUMBER" \
  --arg force "$FORCE_LOCK"

# Acquire lock
if ! acquire_lock "$ISSUE_NUMBER" "$FORCE_LOCK"; then
  log_event "lock_failed" --arg issue "$ISSUE_NUMBER"
  exit 1
fi

# Signal handler for graceful shutdown
WORKER_STATE="initializing"
handle_signal() {
  local signal="$1"
  log_event "signal_received" --arg signal "$signal" --arg state "$WORKER_STATE"

  if [ "$WORKER_STATE" = "executing" ]; then
    echo ""
    echo "[worker] Interrupted during execution - work may be incomplete"
    gh issue edit "$ISSUE_NUMBER" --add-label "worker:partial" 2>/dev/null || true
  fi

  release_lock
  log_session_end "interrupted" "130"
  exit 130
}
trap 'handle_signal SIGTERM' SIGTERM
trap 'handle_signal SIGINT' SIGINT

# --- Check current issue state ---
WORKER_STATE="checking_state"
log_event "state_check" --arg issue "$ISSUE_NUMBER"

ISSUE_LABELS=$(gh issue view "$ISSUE_NUMBER" --json labels -q '.labels[].name' 2>/dev/null || echo "")

# If awaiting approval, check for approval
if echo "$ISSUE_LABELS" | grep -q "worker:awaiting-approval"; then
  echo "[worker] Issue in awaiting-approval state - checking for approval..."

  # Check for thumbs up reaction on plan comment
  # Note: No leading slash - Git Bash on Windows converts /repos to filesystem path
  PLAN_COMMENT_ID=$(gh api "repos/{owner}/{repo}/issues/${ISSUE_NUMBER}/comments" \
    --jq '.[] | select(.body | contains("## Execution Plan")) | .id' 2>/dev/null | tail -1)

  if [ -n "$PLAN_COMMENT_ID" ]; then
    APPROVAL_COUNT=$(gh api "repos/{owner}/{repo}/issues/comments/${PLAN_COMMENT_ID}/reactions" \
      --jq '[.[] | select(.content == "+1")] | length' 2>/dev/null || echo "0")

    if [ "$APPROVAL_COUNT" -gt 0 ]; then
      echo "[worker] ✓ Approval received - proceeding with execution"
      log_event "approval_received" --arg comment_id "$PLAN_COMMENT_ID"

      # Remove awaiting-approval, add executing
      gh issue edit "$ISSUE_NUMBER" \
        --remove-label "worker:awaiting-approval" \
        --add-label "worker:executing" 2>/dev/null || true

      # Skip to execution phase
      WORKER_STATE="approved"
    else
      echo "[worker] Plan not yet approved"
      echo ""
      echo "To approve: Add a 👍 reaction to the Execution Plan comment"
      echo "Then re-run: $0 --issue $ISSUE_NUMBER"
      release_lock
      log_session_end "awaiting_approval" "0"
      exit 0
    fi
  else
    echo "[error] Could not find plan comment - issue may be in inconsistent state"
    release_lock
    exit 1
  fi
fi

# --- Parse issue (if not approved yet) ---
if [ "$WORKER_STATE" != "approved" ]; then
  WORKER_STATE="parsing"
  echo "[worker] Parsing issue #${ISSUE_NUMBER}..."

  if ! parse_issue_body "$ISSUE_NUMBER"; then
    log_event "parse_failed" --arg issue "$ISSUE_NUMBER"
    gh issue comment "$ISSUE_NUMBER" --body "## Worker Error

Failed to parse issue body. Please ensure the issue has:
- \`## Summary\` section
- \`## Acceptance Criteria\` section

See issue template for expected format." 2>/dev/null || true
    release_lock
    log_session_end "parse_error" "1"
    exit 1
  fi

  log_event "issue_parsed" \
    --arg title "$ISSUE_TITLE" \
    --arg summary "$ISSUE_SUMMARY" \
    --arg acceptance "$ISSUE_ACCEPTANCE"

  echo "[worker] ✓ Issue: $ISSUE_TITLE"

  # Validate required sections
  if ! validate_issue_for_worker; then
    release_lock
    log_session_end "validation_error" "1"
    exit 1
  fi

  # --- Generate execution plan ---
  WORKER_STATE="planning"
  echo ""
  echo "[worker] Generating execution plan..."

  # Set planning label
  gh issue edit "$ISSUE_NUMBER" --add-label "worker:planning" 2>/dev/null || true

  # Get current commit SHA for traceability
  BASE_SHA=$(git rev-parse HEAD)

  # Plan comment body
  PLAN_BODY="## Execution Plan

**Issue:** #${ISSUE_NUMBER} - ${ISSUE_TITLE}

**Summary:**
${ISSUE_SUMMARY}

**Acceptance Criteria:**
${ISSUE_ACCEPTANCE}

**Based on:** \`main @ ${BASE_SHA:0:7}\`

---

**Proposed approach:**

_Worker will implement changes to satisfy the acceptance criteria above._

---

**Next:** React with 👍 to approve execution

<!-- agent:metadata
status: awaiting_approval
agent: claude-worker
plan_generated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
base_sha: $BASE_SHA
-->"

  # Post plan comment
  echo "[worker] Posting execution plan..."
  gh issue comment "$ISSUE_NUMBER" --body "$PLAN_BODY" 2>/dev/null

  log_event "plan_posted" --arg base_sha "$BASE_SHA"

  # Update labels
  gh issue edit "$ISSUE_NUMBER" \
    --remove-label "worker:planning" \
    --add-label "worker:awaiting-approval" 2>/dev/null || true

  echo ""
  echo "[worker] ✓ Plan posted to issue #${ISSUE_NUMBER}"
  echo ""
  echo "Next steps:"
  echo "  1. Review the execution plan in the issue comment"
  echo "  2. React with 👍 to approve"
  echo "  3. Re-run: $0 --issue $ISSUE_NUMBER"

  release_lock
  log_session_end "awaiting_approval" "0"
  exit 0
fi

# --- Sub-agent Execution Function ---

# Execute with sub-agents in parallel waves
# Args: plan_file, worktree_path
# Returns: 0 on success, 1 on failure
execute_with_subagents() {
  local plan_file="$1"
  local worktree_path="$2"

  echo "[subagent] Starting parallel execution with sub-agents" >&2

  # Extract execution graph
  local yaml_block
  if ! yaml_block=$(extract_execution_graph "$plan_file"); then
    echo "[subagent] Failed to extract execution graph" >&2
    return 1
  fi

  # Validate DAG (no cycles)
  if ! validate_dag "$yaml_block"; then
    echo "[subagent] Invalid execution graph - contains cycles" >&2
    return 1
  fi

  echo "[subagent] ✓ Execution graph validated" >&2

  # Track completed tasks
  declare -a completed_tasks=()
  local wave_num=1

  # Process waves until all tasks complete
  while true; do
    # Get ready tasks (no dependencies or all dependencies met)
    local ready_tasks
    ready_tasks=$(get_ready_tasks "$yaml_block" 2>/dev/null || echo "")

    # Filter out already completed tasks
    local pending_ready=""
    while IFS= read -r task_id; do
      if [ -n "$task_id" ]; then
        local already_done=false
        for completed_task in "${completed_tasks[@]}"; do
          if [ "$task_id" = "$completed_task" ]; then
            already_done=true
            break
          fi
        done

        if [ "$already_done" = false ]; then
          pending_ready+="$task_id"$'\n'
        fi
      fi
    done <<< "$ready_tasks"

    # Remove trailing newline
    pending_ready=$(echo "$pending_ready" | sed '/^$/d')

    if [ -z "$pending_ready" ]; then
      echo "[subagent] No more ready tasks - execution complete" >&2
      break
    fi

    local task_count
    task_count=$(echo "$pending_ready" | wc -l | tr -d ' ')
    echo "[subagent] Wave $wave_num: $task_count ready tasks" >&2

    # Build wave tasks JSON
    local wave_tasks_json="["
    local first=true

    while IFS= read -r task_id; do
      if [ -z "$task_id" ]; then
        continue
      fi

      # Extract task properties
      local task_name write_scope command
      task_name=$(get_task_property "$yaml_block" "$task_id" "name" 2>/dev/null || echo "$task_id")
      write_scope=$(get_task_property "$yaml_block" "$task_id" "write_scope" 2>/dev/null || echo "[]")
      command=$(get_task_property "$yaml_block" "$task_id" "command" 2>/dev/null || echo "echo 'No command defined'")

      # Build task JSON
      if [ "$first" = false ]; then
        wave_tasks_json+=","
      fi
      first=false

      wave_tasks_json+=$(jq -n \
        --arg id "$task_id" \
        --arg name "$task_name" \
        --arg cmd "$command" \
        --argjson scope "$write_scope" \
        --arg wave "$wave_num" \
        '{
          id: $id,
          name: $name,
          command: $cmd,
          write_scope: $scope,
          wave: ($wave | tonumber)
        }')
    done <<< "$pending_ready"

    wave_tasks_json+="]"

    # Log wave start
    log_event "subagent_execution_start" \
      --arg wave "$wave_num" \
      --arg task_count "$task_count"

    # Spawn wave
    local wave_id="wave-$wave_num"
    local parent_id="${WORKER_ID:-claude-worker}"

    if spawn_wave "$wave_tasks_json" "$parent_id"; then
      # Aggregate results
      if aggregate_wave_results "$wave_id"; then
        # Create wave commit
        local completed_agents
        completed_agents=$(jq -r '.agents[]? | select(.status == "complete") | .id' \
          "$WORKER_DIR/waves/$wave_id/agents.json" 2>/dev/null || echo "")

        create_wave_commit "$wave_num" "$completed_agents"

        # Mark tasks as completed
        while IFS= read -r task_id; do
          if [ -n "$task_id" ]; then
            completed_tasks+=("$task_id")
          fi
        done <<< "$pending_ready"

        log_event "wave_complete" \
          --arg wave "$wave_num" \
          --arg completed "$task_count"
      else
        echo "[subagent] Wave $wave_num aggregation failed" >&2

        # Handle failure with salvage
        if handle_wave_failure "$wave_id" "unknown"; then
          echo "[subagent] Partial salvage succeeded - continuing" >&2
        else
          echo "[subagent] Wave failed - aborting" >&2
          return 1
        fi
      fi
    else
      echo "[subagent] Wave $wave_num failed to spawn" >&2
      return 1
    fi

    wave_num=$((wave_num + 1))
  done

  log_event "subagent_execution_complete" \
    --arg total_waves "$wave_num" \
    --arg total_tasks "${#completed_tasks[@]}"

  echo "[subagent] ✓ All waves complete" >&2
  return 0
}

# --- Execution phase (reached after approval) ---
WORKER_STATE="executing"
START_TIME=$(date +%s)

echo ""
echo "[worker] Starting execution..."
log_event "execution_start" --arg timestamp "$START_TIME"

# Audit: Log execution start
log_audit_event "execution_start" \
  --arg agent "$AGENT_NAME" \
  --arg issue "$ISSUE_NUMBER" \
  --arg timestamp "$START_TIME"

# Re-parse issue to get current data
parse_issue_body "$ISSUE_NUMBER"

# Create worktree
BRANCH_NAME="issue/${ISSUE_NUMBER}"
REPO_NAME=$(basename "$REPO_ROOT")
# Match worktree-create.sh pattern: {repo}-{branch}
WORKTREE_PATH="$(dirname "$REPO_ROOT")/${REPO_NAME}-${BRANCH_NAME}"

echo "[worker] Creating worktree: $WORKTREE_PATH"
"$SCRIPTS_DIR/worktree-create.sh" "$BRANCH_NAME" "main"

log_event "worktree_created" \
  --arg path "$WORKTREE_PATH" \
  --arg branch "$BRANCH_NAME"

# Post start comment
gh issue comment "$ISSUE_NUMBER" --body "## Execution Started

**Worktree:** \`$WORKTREE_PATH\`
**Branch:** \`$BRANCH_NAME\`
**Started:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Executing based on approved plan...

<!-- agent:metadata
status: executing
agent: claude-worker
execution_started_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
worktree: $WORKTREE_PATH
-->" 2>/dev/null || true

# Change to worktree
cd "$WORKTREE_PATH"
echo "[worker] Working in: $(pwd)"

# ===== INVOKE CLAUDE FOR IMPLEMENTATION =====
echo ""
echo "[worker] Determining execution mode..."

# Check for execution graph in issue body or PLAN.md
PLAN_FILE=".worker/plans/issue-${ISSUE_NUMBER}-PLAN.md"
EXECUTION_MODE="serial"

if [ -f "$PLAN_FILE" ]; then
  if extract_execution_graph "$PLAN_FILE" > /dev/null 2>&1; then
    EXECUTION_MODE="parallel"
    log_event "execution_mode" "parallel" "Execution graph detected"
    echo "[worker] Execution graph detected - parallel mode available"
  else
    log_event "execution_mode" "serial" "No execution graph, using serial"
    echo "[worker] No execution graph - using serial mode"
  fi
else
  log_event "execution_mode" "serial" "No PLAN.md file"
  echo "[worker] No PLAN.md file - using serial mode"
fi

# Override to serial if --serial flag set
if [ "$FORCE_SERIAL" = true ]; then
  EXECUTION_MODE="serial"
  echo "[worker] --serial flag set - forcing serial execution"
fi

# Execute based on mode
if [ "$EXECUTION_MODE" = "serial" ]; then
  echo ""
  echo "[worker] Invoking Claude for implementation (serial mode)..."

  CLAUDE_PROMPT="You are implementing GitHub issue #${ISSUE_NUMBER}.

**Title:** ${ISSUE_TITLE}

**Summary:**
${ISSUE_SUMMARY}

**Acceptance Criteria:**
${ISSUE_ACCEPTANCE}

**Working directory:** $(pwd)
**Branch:** ${BRANCH_NAME}

Instructions:
1. Analyze the acceptance criteria
2. Make the necessary code changes to satisfy each criterion
3. Stage your changes with 'git add <specific-files>'
4. Do NOT commit - the orchestrator will handle the commit

When done, confirm what changes you made."

  # Call Claude to do the actual implementation work
  # Using print mode to pass the prompt
  if command -v claude &> /dev/null; then
    claude -p "$CLAUDE_PROMPT" --allowedTools "Bash,Read,Write,Edit,Glob,Grep"
  else
    echo "[error] Claude CLI not found - cannot execute AI work"
    echo "[worker] Manual implementation required in: $WORKTREE_PATH"
    echo ""
    echo "After implementing changes manually:"
    echo "  1. Stage changes: git add <files>"
    echo "  2. Re-run this script to complete"
    release_lock
    log_session_end "manual_required" "0"
    exit 0
  fi
else
  # Parallel execution with sub-agents
  echo ""
  echo "[worker] Executing with sub-agents (parallel mode)..."

  if ! execute_with_subagents "$PLAN_FILE" "$WORKTREE_PATH"; then
    echo "[error] Sub-agent execution failed"
    release_lock
    log_session_end "subagent_failed" "1"
    exit 1
  fi
fi

# ==================================

echo ""
echo "[worker] Execution complete - creating commit..."

# Check if there are staged changes
if git diff --cached --quiet; then
  echo "[warning] No staged changes to commit"
  log_event "no_changes" --arg issue "$ISSUE_NUMBER"

  # Still create PR with empty commit if nothing to commit
  git commit --allow-empty -m "No changes needed for issue #${ISSUE_NUMBER}"
fi

# Single commit with all staged changes
COMMIT_MSG="$(echo "$ISSUE_TITLE" | sed 's/\[.*\]//' | xargs)

Resolves #${ISSUE_NUMBER}

Acceptance Criteria:
$(echo "$ISSUE_ACCEPTANCE" | sed 's/^/  /')

Co-Authored-By: Claude Worker <claude@anthropic.com>"

git commit -m "$COMMIT_MSG" 2>/dev/null || true

# Push branch
echo "[worker] Pushing branch..."
git push -u origin "$BRANCH_NAME" 2>&1 || {
  echo "[error] Failed to push branch"
  log_audit_event "execution_failed" \
    --arg agent "$AGENT_NAME" \
    --arg issue "$ISSUE_NUMBER" \
    --arg reason "push_failed"
  release_lock
  log_session_end "push_failed" "1"
  exit 1
}

log_event "branch_pushed" --arg branch "$BRANCH_NAME"

# Create PR
echo "[worker] Creating PR..."
cd "$REPO_ROOT"

PR_URL=$(gh pr create \
  --title "$ISSUE_TITLE" \
  --body "## Summary

Implements #${ISSUE_NUMBER}

## Changes

See commit history for details.

## Acceptance Criteria

${ISSUE_ACCEPTANCE}

---

<!-- agent:metadata
issue: ${ISSUE_NUMBER}
agent: claude-worker
-->

Closes #${ISSUE_NUMBER}" \
  --head "$BRANCH_NAME" \
  --base "main" 2>&1) || {
  echo "[error] Failed to create PR"
  log_audit_event "execution_failed" \
    --arg agent "$AGENT_NAME" \
    --arg issue "$ISSUE_NUMBER" \
    --arg reason "pr_failed"
  release_lock
  log_session_end "pr_failed" "1"
  exit 1
}

PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || echo "unknown")

log_event "pr_created" \
  --arg pr_number "$PR_NUMBER" \
  --arg pr_url "$PR_URL"

# Calculate duration
END_TIME=$(date +%s)
DURATION_SECONDS=$((END_TIME - START_TIME))
DURATION_MINUTES=$((DURATION_SECONDS / 60))
DURATION_REMAINDER=$((DURATION_SECONDS % 60))
DURATION="${DURATION_MINUTES}m ${DURATION_REMAINDER}s"

# Post completion comment
gh issue comment "$ISSUE_NUMBER" --body "## Work Complete

Created PR #${PR_NUMBER}

<details>
<summary>Execution Summary</summary>

**Duration:** $DURATION
**Branch:** \`$BRANCH_NAME\`
**PR:** $PR_URL

**Acceptance Criteria Status:**
$(echo "$ISSUE_ACCEPTANCE" | sed 's/- \[ \]/- [x]/g')

</details>

<!-- agent:metadata
status: complete
agent: claude-worker
completed_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
duration: $DURATION
pr_number: $PR_NUMBER
-->" 2>/dev/null || true

# Update labels
gh issue edit "$ISSUE_NUMBER" \
  --remove-label "worker:executing" \
  --add-label "worker:complete" 2>/dev/null || true

# Update project status if script exists
if [ -f "$SCRIPTS_DIR/github/issue-update-status.sh" ]; then
  "$SCRIPTS_DIR/github/issue-update-status.sh" "$ISSUE_NUMBER" "In Review" 2>/dev/null || true
fi

echo ""
echo "[worker] ✓ Execution complete"
echo "  PR: $PR_URL"
echo "  Duration: $DURATION"

log_event "execution_complete" \
  --arg pr_number "$PR_NUMBER" \
  --arg duration "$DURATION"

# Audit: Log execution complete
log_audit_event "execution_complete" \
  --arg agent "$AGENT_NAME" \
  --arg issue "$ISSUE_NUMBER" \
  --arg pr_number "$PR_NUMBER" \
  --arg duration "$DURATION"

release_lock
log_session_end "complete" "0"

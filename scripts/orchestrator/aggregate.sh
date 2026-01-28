#!/usr/bin/env bash
#
# Status Aggregation Script
# Queries GitHub for worker state and provides tiered output formats
#
# Usage:
#   ./scripts/orchestrator/aggregate.sh                        # Default: table format
#   ./scripts/orchestrator/aggregate.sh --format oneliner      # Quick summary
#   ./scripts/orchestrator/aggregate.sh --format table         # Progress view
#   ./scripts/orchestrator/aggregate.sh --format detailed      # Full JSON output
#   ./scripts/orchestrator/aggregate.sh --scope active         # Only active workers (default)
#   ./scripts/orchestrator/aggregate.sh --scope phase          # All issues in current phase
#   ./scripts/orchestrator/aggregate.sh --scope all            # All issues
#   ./scripts/orchestrator/aggregate.sh --cascade 42           # Show cascade impact for issue 42
#
# Invokable by:
#   - Human from command line for quick status checks
#   - Orchestrator (Gemini) for CEO status reports
#

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Parse arguments ---
FORMAT="table"
SCOPE="active"
CASCADE_ISSUE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --scope)
      SCOPE="$2"
      shift 2
      ;;
    --cascade)
      CASCADE_ISSUE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--format FORMAT] [--scope SCOPE] [--cascade ISSUE]"
      echo ""
      echo "Query GitHub for worker status and provide tiered output."
      echo ""
      echo "Options:"
      echo "  --format FORMAT   Output format: oneliner, table, detailed (default: table)"
      echo "  --scope SCOPE     Query scope: active, phase, all (default: active)"
      echo "  --cascade ISSUE   Show cascade impact for failed issue"
      echo "  --help            Show this help message"
      echo ""
      echo "Formats:"
      echo "  oneliner   Quick summary: '3 executing, 2 awaiting approval, 1 blocked'"
      echo "  table      Icon-based progress view with status, issue, and title"
      echo "  detailed   Full JSON output with comments, timestamps, assignees"
      echo ""
      echo "Scopes:"
      echo "  active     Only issues with worker:* labels (default)"
      echo "  phase      All open issues (current phase)"
      echo "  all        All issues including closed"
      echo ""
      echo "Examples:"
      echo "  $0                           # Table view of active workers"
      echo "  $0 --format oneliner         # Quick count summary"
      echo "  $0 --cascade 42              # Show issues blocked by #42"
      exit 0
      ;;
    *)
      echo "[error] Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate format
case $FORMAT in
  oneliner|table|detailed)
    ;;
  *)
    echo "[error] Invalid format: $FORMAT"
    echo "Valid formats: oneliner, table, detailed"
    exit 1
    ;;
esac

# Validate scope
case $SCOPE in
  active|phase|all)
    ;;
  *)
    echo "[error] Invalid scope: $SCOPE"
    echo "Valid scopes: active, phase, all"
    exit 1
    ;;
esac

# --- Helper Functions ---

# Get status icon (text-based for Windows compatibility)
# From 04-04 decision: text-based severity markers instead of emojis
get_status_icon() {
  local state="$1"
  case $state in
    complete)          echo "[OK]" ;;
    executing)         echo "[..]" ;;
    awaiting-approval) echo "[??]" ;;
    planning)          echo "[..]" ;;
    failed)            echo "[XX]" ;;
    partial)           echo "[--]" ;;
    blocked)           echo "[--]" ;;
    cascade-blocked)   echo "[--]" ;;
    *)                 echo "[  ]" ;;
  esac
}

# Get state priority for sorting (lower = more important)
get_state_priority() {
  local state="$1"
  case $state in
    failed)            echo "1" ;;
    awaiting-approval) echo "2" ;;
    executing)         echo "3" ;;
    planning)          echo "4" ;;
    blocked)           echo "5" ;;
    cascade-blocked)   echo "5" ;;
    partial)           echo "6" ;;
    complete)          echo "7" ;;
    *)                 echo "9" ;;
  esac
}

# Count issues by worker state
count_by_state() {
  local state="$1"
  gh issue list --label "worker:${state}" --state open --json number --jq 'length' 2>/dev/null || echo "0"
}

# Count blocked issues (not worker state, but blocked label)
count_blocked() {
  gh issue list --label "blocked" --state open --json number --jq 'length' 2>/dev/null || echo "0"
}

# --- Main Aggregation Functions ---

# Format: oneliner - Quick summary for fast status check
format_oneliner() {
  local executing=$(count_by_state "executing")
  local awaiting=$(count_by_state "awaiting-approval")
  local planning=$(count_by_state "planning")
  local complete=$(count_by_state "complete")
  local failed=$(count_by_state "failed")
  local blocked=$(count_blocked)

  local parts=()
  [ "$executing" -gt 0 ] && parts+=("$executing executing")
  [ "$planning" -gt 0 ] && parts+=("$planning planning")
  [ "$awaiting" -gt 0 ] && parts+=("$awaiting awaiting approval")
  [ "$failed" -gt 0 ] && parts+=("$failed failed")
  [ "$blocked" -gt 0 ] && parts+=("$blocked blocked")
  [ "$complete" -gt 0 ] && parts+=("$complete complete")

  if [ ${#parts[@]} -eq 0 ]; then
    echo "No active workers"
  else
    local IFS=", "
    echo "${parts[*]}"
  fi
}

# Format: table - Icon-based progress view
format_table() {
  local scope="$1"

  # Build label filter based on scope
  local label_filter=""
  local state_filter="--state open"

  case $scope in
    active)
      # Query each worker state separately and combine (gh doesn't support OR for labels)
      ;;
    phase)
      state_filter="--state open"
      ;;
    all)
      state_filter="--state all"
      ;;
  esac

  echo "Status | Issue  | Title"
  echo "-------|--------|----------------------------------------------"

  if [ "$scope" = "active" ]; then
    # For active scope, query worker-labeled issues only
    local results=""

    # Query each worker state and combine
    for state in executing awaiting-approval planning failed partial complete; do
      local issues
      issues=$(gh issue list --label "worker:${state}" --state open --json number,title --jq '.[] | {number, title, state: "'"${state}"'"}' 2>/dev/null || echo "")
      if [ -n "$issues" ]; then
        results="${results}${issues}"$'\n'
      fi
    done

    # Also get failed/closed complete issues if any
    local closed_complete
    closed_complete=$(gh issue list --label "worker:complete" --state closed --json number,title --jq '.[] | {number, title, state: "complete"}' 2>/dev/null || echo "")
    if [ -n "$closed_complete" ]; then
      results="${results}${closed_complete}"$'\n'
    fi

    if [ -z "$results" ] || [ "$results" = $'\n' ]; then
      echo "       | (none) | No active workers found"
      return
    fi

    # Process and display results sorted by state priority
    echo "$results" | jq -rs '
      sort_by(
        if .state == "failed" then 1
        elif .state == "awaiting-approval" then 2
        elif .state == "executing" then 3
        elif .state == "planning" then 4
        elif .state == "blocked" then 5
        elif .state == "partial" then 6
        elif .state == "complete" then 7
        else 9 end
      ) | .[] | select(.number != null) |
      "\(
        if .state == "complete" then "[OK]"
        elif .state == "executing" then "[..]"
        elif .state == "awaiting-approval" then "[??]"
        elif .state == "planning" then "[..]"
        elif .state == "failed" then "[XX]"
        elif .state == "partial" then "[--]"
        else "[  ]" end
      ) | #\(.number | tostring | if length < 5 then . + (" " * (5 - length)) else . end) | \(.title[0:45])"
    ' 2>/dev/null || echo "       | (none) | Error querying issues"
  else
    # For phase/all scope, query all issues and check for worker labels
    gh issue list $state_filter --json number,title,labels --jq '
      .[] |
      (.labels | map(select(.name | startswith("worker:"))) | .[0].name // "none") as $worker_label |
      (.labels | map(.name) | if any(. == "blocked") then "blocked" else null end) as $blocked |
      {
        number,
        title,
        state: (if $worker_label != "none" then ($worker_label | sub("worker:"; "")) else (if $blocked then "blocked" else "open" end) end)
      }
    ' 2>/dev/null | jq -rs '
      sort_by(
        if .state == "failed" then 1
        elif .state == "awaiting-approval" then 2
        elif .state == "executing" then 3
        elif .state == "planning" then 4
        elif .state == "blocked" then 5
        elif .state == "partial" then 6
        elif .state == "complete" then 7
        else 9 end
      ) | .[] | select(.number != null) |
      "\(
        if .state == "complete" then "[OK]"
        elif .state == "executing" then "[..]"
        elif .state == "awaiting-approval" then "[??]"
        elif .state == "planning" then "[..]"
        elif .state == "failed" then "[XX]"
        elif .state == "partial" then "[--]"
        elif .state == "blocked" then "[--]"
        else "[  ]" end
      ) | #\(.number | tostring | if length < 5 then . + (" " * (5 - length)) else . end) | \(.title[0:45])"
    ' 2>/dev/null || echo "       | (none) | Error querying issues"
  fi
}

# Format: detailed - Full JSON output with metadata
format_detailed() {
  local scope="$1"

  local state_filter="--state open"
  case $scope in
    all)
      state_filter="--state all"
      ;;
  esac

  if [ "$scope" = "active" ]; then
    # For active scope, only get worker-labeled issues
    local all_results="[]"

    for state in executing awaiting-approval planning failed partial complete; do
      local issues
      issues=$(gh issue list --label "worker:${state}" --state open --json number,title,labels,comments,updatedAt,assignees 2>/dev/null || echo "[]")
      all_results=$(echo "$all_results" "$issues" | jq -s 'add')
    done

    # Also include closed complete issues
    local closed
    closed=$(gh issue list --label "worker:complete" --state closed --json number,title,labels,comments,updatedAt,assignees 2>/dev/null || echo "[]")
    all_results=$(echo "$all_results" "$closed" | jq -s 'add')

    echo "$all_results" | jq '
      map({
        issue: .number,
        title: .title,
        state: (.labels | map(select(.name | startswith("worker:"))) | .[0].name // "unknown" | sub("worker:"; "")),
        assignee: (.assignees[0].login // "unassigned"),
        updated: .updatedAt,
        comment_count: (.comments | length)
      }) | sort_by(.issue)
    '
  else
    # For phase/all scope, get all issues
    gh issue list $state_filter --json number,title,labels,comments,updatedAt,assignees --jq '
      map({
        issue: .number,
        title: .title,
        state: ((.labels | map(select(.name | startswith("worker:"))) | .[0].name // "open") | sub("worker:"; "")),
        blocked: (.labels | map(.name) | any(. == "blocked")),
        assignee: (.assignees[0].login // "unassigned"),
        updated: .updatedAt,
        comment_count: (.comments | length)
      }) | sort_by(.issue)
    ' 2>/dev/null || echo "[]"
  fi
}

# --- Cascade Detection Functions ---

# Detect issues blocked by a specific issue
detect_cascade() {
  local failed_issue="$1"

  # Find issues with "Blocked by #N" in body
  local direct_dependents
  direct_dependents=$(gh issue list --state open --json number,body --jq '
    .[] |
    select(.body != null) |
    select(.body | test("Blocked by #'"${failed_issue}"'([^0-9]|$)"; "i")) |
    .number
  ' 2>/dev/null || echo "")

  if [ -z "$direct_dependents" ]; then
    return
  fi

  echo "$direct_dependents"

  # Find transitive dependents (issues blocked by issues blocked by the failed issue)
  for dep in $direct_dependents; do
    detect_cascade "$dep" 2>/dev/null | while read -r transitive; do
      # Avoid duplicates
      if ! echo "$direct_dependents" | grep -q "^${transitive}$"; then
        echo "$transitive"
      fi
    done
  done
}

# Generate failure report for CEO
report_failure() {
  local failed_issue="$1"

  # Get issue details
  local issue_info
  issue_info=$(gh issue view "$failed_issue" --json title,body,comments 2>/dev/null || echo "{}")

  local title
  title=$(echo "$issue_info" | jq -r '.title // "Unknown"')

  # Extract error context from comments (look for error patterns)
  local error_context
  error_context=$(echo "$issue_info" | jq -r '
    .comments | map(.body) | map(select(test("error|fail|exception"; "i"))) | .[0] // "No error details in comments"
  ' 2>/dev/null || echo "No error details available")

  # Get cascade
  local cascade
  cascade=$(detect_cascade "$failed_issue" | sort -u)

  echo "[XX] Issue #${failed_issue} failed: \"${title}\""
  echo ""
  echo "Error context:"
  echo "  $(echo "$error_context" | head -c 200)"
  echo ""

  if [ -n "$cascade" ]; then
    echo "Cascade impact:"
    for dep in $cascade; do
      local dep_title
      dep_title=$(gh issue view "$dep" --json title --jq '.title' 2>/dev/null || echo "Unknown")
      echo "  - #${dep}: ${dep_title}"
    done
  else
    echo "Cascade impact: None (no dependent issues)"
  fi

  echo ""
  echo "Options:"
  echo "  1. retry   - Re-run worker for #${failed_issue}"
  echo "  2. modify  - Update issue scope and retry"
  echo "  3. abandon - Close #${failed_issue} and unblock dependents manually"
}

# Label cascade-blocked issues
label_cascade_blocked() {
  local failed_issue="$1"

  local cascade
  cascade=$(detect_cascade "$failed_issue" | sort -u)

  if [ -z "$cascade" ]; then
    echo "[orchestrator] No cascade impact for issue #${failed_issue}"
    return
  fi

  echo "[orchestrator] Labeling cascade-blocked issues for #${failed_issue}:"

  for dep in $cascade; do
    echo "  - Adding cascade-blocked label to #${dep}"

    # Add label
    gh issue edit "$dep" --add-label "cascade-blocked" 2>/dev/null || true

    # Post comment
    gh issue comment "$dep" --body "## Cascade Blocked

This issue is blocked by #${failed_issue}, which has failed.

**Options:**
- Fix #${failed_issue} and retry
- Skip dependency if no longer relevant
- Abandon this issue if blocked permanently

Waiting for CEO decision." 2>/dev/null || true
  done
}

# --- Main Execution ---

# Handle cascade mode
handle_cascade() {
  local issue_num="$1"

  echo "[orchestrator] Cascade analysis for issue #${issue_num}"
  echo ""

  # Check if issue exists and is failed
  local issue_labels
  issue_labels=$(gh issue view "$issue_num" --json labels --jq '.labels[].name' 2>/dev/null || echo "")

  if echo "$issue_labels" | grep -q "worker:failed"; then
    report_failure "$issue_num"
  else
    echo "Note: Issue #${issue_num} is not currently marked as failed"
    echo ""
    echo "Cascade (issues that would be blocked if #${issue_num} fails):"

    local cascade
    cascade=$(detect_cascade "$issue_num" | sort -u)

    if [ -n "$cascade" ]; then
      for dep in $cascade; do
        local dep_title
        dep_title=$(gh issue view "$dep" --json title --jq '.title' 2>/dev/null || echo "Unknown")
        echo "  - #${dep}: ${dep_title}"
      done
    else
      echo "  (none)"
    fi
  fi
}

if [ -n "$CASCADE_ISSUE" ]; then
  handle_cascade "$CASCADE_ISSUE"
  exit 0
fi

# Normal aggregation mode
aggregate_status() {
  local format="$1"
  local scope="$2"

  case $format in
    oneliner)
      format_oneliner
      ;;
    table)
      format_table "$scope"
      ;;
    detailed)
      format_detailed "$scope"
      ;;
  esac
}

aggregate_status "$FORMAT" "$SCOPE"

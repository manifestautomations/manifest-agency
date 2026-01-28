#!/usr/bin/env bash
# graph.sh - Dependency graph builder for orchestrator
#
# Builds and analyzes issue dependencies for execution ordering.
# Uses tsort for topological sort and cycle detection.
#
# Usage:
#   source scripts/orchestrator/graph.sh
#   build_dependency_graph
#   get_execution_order
#   get_ready_issues
#   detect_cascade 42
#
# Or direct invocation:
#   ./graph.sh --help
#   ./graph.sh graph
#   ./graph.sh order
#   ./graph.sh ready
#   ./graph.sh cascade 42
#
# Dependency format in issue body:
#   "Blocked by #N" - declares dependency on issue N
#   Multiple dependencies: "Blocked by #42" and "Blocked by #43" on separate lines

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Functions ---

# Build dependency graph from GitHub issues
# Queries open issues and extracts "Blocked by #N" patterns
# Returns: Lines in format "dependency issue" (for tsort input)
# Example output:
#   42 45   (issue 45 depends on 42)
#   42 46   (issue 46 depends on 42)
#   43 46   (issue 46 depends on 43)
build_dependency_graph() {
  local state="${1:-open}"

  # Query issues with their bodies
  local issues_json
  issues_json=$(gh issue list --state "$state" --json number,body --limit 500 2>/dev/null) || {
    echo "[error] Failed to query GitHub issues" >&2
    return 1
  }

  # Check if we got results
  if [ -z "$issues_json" ] || [ "$issues_json" = "[]" ]; then
    # No issues found - return empty (valid state)
    return 0
  fi

  # Extract dependency edges using jq
  # Pattern: "Blocked by #N" where N is issue number
  # Output: "dependency issue" pairs (dependency must complete before issue)
  echo "$issues_json" | jq -r '
    .[] |
    .number as $issue |
    .body // "" |
    # Find all "Blocked by #N" patterns (case insensitive)
    scan("[Bb]locked by #([0-9]+)") |
    .[0] as $dep |
    # Output: dependency -> issue (dependency must complete first)
    "\($dep) \($issue)"
  ' 2>/dev/null || true
}

# Get execution order using topological sort
# Returns: Issue numbers in valid execution order (dependencies first)
# Exits with error if circular dependency detected
get_execution_order() {
  local state="${1:-open}"

  # Build dependency graph
  local graph
  graph=$(build_dependency_graph "$state")

  # If no dependencies, return all open issues in any order
  if [ -z "$graph" ]; then
    gh issue list --state "$state" --json number --jq '.[].number' 2>/dev/null | sort -n
    return 0
  fi

  # Use tsort to compute topological order
  # tsort exits non-zero if cycle detected
  local sorted
  sorted=$(echo "$graph" | tsort 2>&1) || {
    local error_msg="$sorted"
    echo "[error] Cycle detected in dependency graph" >&2
    echo "[detail] tsort output: $error_msg" >&2
    return 1
  }

  # tsort only includes issues with dependencies
  # Need to add issues without any dependencies
  local all_issues
  all_issues=$(gh issue list --state "$state" --json number --jq '.[].number' 2>/dev/null | sort -n)

  # Combine: sorted issues + issues not in dependency graph
  # (issues without dependencies can run anytime, put them first)
  {
    # First: issues not mentioned in any dependency
    for issue in $all_issues; do
      if ! echo "$graph" | grep -qE "(^|[[:space:]])$issue([[:space:]]|$)"; then
        echo "$issue"
      fi
    done

    # Then: topologically sorted issues
    echo "$sorted"
  } | awk '!seen[$0]++'  # Remove duplicates while preserving order
}

# Get issues ready for dispatch (no unresolved dependencies)
# Returns: Issue numbers that can be executed immediately
get_ready_issues() {
  local state="${1:-open}"

  # Get all open issues
  local all_issues
  all_issues=$(gh issue list --state "$state" --json number,body --limit 500 2>/dev/null) || {
    echo "[error] Failed to query GitHub issues" >&2
    return 1
  }

  if [ -z "$all_issues" ] || [ "$all_issues" = "[]" ]; then
    return 0
  fi

  # Get closed issues (resolved dependencies)
  local closed_issues
  closed_issues=$(gh issue list --state closed --json number --jq '.[].number' --limit 1000 2>/dev/null | tr '\n' ' ')

  # For each open issue, check if all blockers are closed
  echo "$all_issues" | jq -r --arg closed "$closed_issues" '
    .[] |
    .number as $issue |
    .body // "" |
    # Extract all blockers
    [scan("[Bb]locked by #([0-9]+)") | .[0]] |
    # Check if all blockers are in closed list or no blockers
    if length == 0 then
      $issue | tostring
    else
      # Filter to blockers NOT in closed list
      map(select(. as $blocker | ($closed | split(" ") | map(select(. != "")) | index($blocker)) == null)) |
      # If no remaining blockers, issue is ready
      if length == 0 then
        $issue | tostring
      else
        empty
      end
    end
  '
}

# Detect cascade of dependent issues when one fails
# Arguments: failed_issue_number
# Returns: Issue numbers that depend on the failed issue (directly or transitively)
detect_cascade() {
  local failed_issue="$1"

  if [ -z "$failed_issue" ]; then
    echo "[error] Issue number required" >&2
    return 1
  fi

  # Build full dependency graph
  local graph
  graph=$(build_dependency_graph "open")

  if [ -z "$graph" ]; then
    # No dependencies - no cascade
    return 0
  fi

  # Find direct dependents (issues that have "Blocked by #failed_issue")
  local direct_deps
  direct_deps=$(echo "$graph" | awk -v issue="$failed_issue" '$1 == issue {print $2}')

  if [ -z "$direct_deps" ]; then
    return 0
  fi

  # For transitive cascade, recursively find all dependents
  local all_cascade="$direct_deps"
  local to_process="$direct_deps"

  while [ -n "$to_process" ]; do
    local next_level=""

    for dep in $to_process; do
      # Find issues blocked by this dependent
      local blocked_by_dep
      blocked_by_dep=$(echo "$graph" | awk -v issue="$dep" '$1 == issue {print $2}')

      for candidate in $blocked_by_dep; do
        # Add if not already in cascade
        if ! echo "$all_cascade" | grep -qw "$candidate"; then
          all_cascade="$all_cascade $candidate"
          next_level="$next_level $candidate"
        fi
      done
    done

    to_process="$next_level"
  done

  # Output sorted unique list
  echo "$all_cascade" | tr ' ' '\n' | sort -nu | grep -v '^$' || true
}

# Get dependency information for a specific issue
# Arguments: issue_number
# Returns: JSON with blockers and dependents
get_issue_dependencies() {
  local issue="$1"

  if [ -z "$issue" ]; then
    echo "[error] Issue number required" >&2
    return 1
  fi

  local graph
  graph=$(build_dependency_graph "all")

  # Find what this issue depends on (blockers)
  local blockers
  blockers=$(echo "$graph" | awk -v issue="$issue" '$2 == issue {print $1}' | sort -n | tr '\n' ',' | sed 's/,$//')

  # Find what depends on this issue
  local dependents
  dependents=$(echo "$graph" | awk -v issue="$issue" '$1 == issue {print $2}' | sort -n | tr '\n' ',' | sed 's/,$//')

  jq -nc \
    --arg issue "$issue" \
    --arg blockers "$blockers" \
    --arg dependents "$dependents" \
    '{
      issue: ($issue | tonumber),
      blocked_by: (if $blockers == "" then [] else ($blockers | split(",") | map(tonumber)) end),
      blocks: (if $dependents == "" then [] else ($dependents | split(",") | map(tonumber)) end)
    }'
}

# Validate dependency graph has no cycles
# Returns: 0 if valid DAG, 1 if cycle detected with error message
validate_graph() {
  local state="${1:-open}"

  local graph
  graph=$(build_dependency_graph "$state")

  if [ -z "$graph" ]; then
    echo "[ok] No dependencies in graph"
    return 0
  fi

  # Count edges
  local edge_count
  edge_count=$(echo "$graph" | wc -l | tr -d ' ')

  # Use tsort to detect cycles
  if echo "$graph" | tsort >/dev/null 2>&1; then
    echo "[ok] Valid DAG with $edge_count dependency edges"
    return 0
  else
    echo "[error] Cycle detected in dependency graph"
    echo ""
    echo "Edges:"
    echo "$graph" | while read -r dep issue; do
      echo "  #$dep blocks #$issue"
    done
    return 1
  fi
}

# --- CLI Interface ---
show_help() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Dependency graph builder for orchestrator.

COMMANDS:
  graph [STATE]     Build and display dependency graph
                    STATE: open (default), closed, all
  order [STATE]     Get execution order (topological sort)
  ready [STATE]     Get issues ready for dispatch (no blockers)
  cascade ISSUE     Detect cascade from failed issue
  deps ISSUE        Get dependencies for specific issue
  validate [STATE]  Validate graph has no cycles

EXAMPLES:
  # Show dependency graph
  $(basename "$0") graph

  # Get execution order
  $(basename "$0") order

  # Find ready issues
  $(basename "$0") ready

  # Detect cascade if issue 42 fails
  $(basename "$0") cascade 42

  # Get dependencies for issue 45
  $(basename "$0") deps 45

  # Validate no cycles
  $(basename "$0") validate

FUNCTIONS (when sourced):
  build_dependency_graph [STATE]
  get_execution_order [STATE]
  get_ready_issues [STATE]
  detect_cascade ISSUE
  get_issue_dependencies ISSUE
  validate_graph [STATE]

OUTPUT FORMAT:
  graph: "dependency issue" pairs (tsort input format)
  order: Issue numbers, one per line, in execution order
  ready: Issue numbers that can be dispatched now
  cascade: Issue numbers blocked by failed issue

EOF
}

# Main CLI handler (when run directly, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    graph)
      build_dependency_graph "${2:-open}"
      ;;
    order)
      get_execution_order "${2:-open}"
      ;;
    ready)
      get_ready_issues "${2:-open}"
      ;;
    cascade)
      if [ -z "${2:-}" ]; then
        echo "[error] Issue number required" >&2
        echo "Usage: $(basename "$0") cascade ISSUE_NUMBER" >&2
        exit 1
      fi
      detect_cascade "$2"
      ;;
    deps)
      if [ -z "${2:-}" ]; then
        echo "[error] Issue number required" >&2
        echo "Usage: $(basename "$0") deps ISSUE_NUMBER" >&2
        exit 1
      fi
      get_issue_dependencies "$2"
      ;;
    validate)
      validate_graph "${2:-open}"
      ;;
    --help|-h|help)
      show_help
      exit 0
      ;;
    "")
      show_help
      exit 0
      ;;
    *)
      echo "[error] Unknown command: $1" >&2
      echo "Use --help for usage" >&2
      exit 1
      ;;
  esac
fi

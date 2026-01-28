#!/usr/bin/env bash
# decompose.sh - Task decomposition helper for orchestrator
#
# Generates prompts for Gemini to decompose CEO intent into vertical slices.
# Validates decomposition output and formats for issue creation.
#
# Usage:
#   source scripts/orchestrator/decompose.sh
#   generate_decomposition_prompt "We need dark mode"
#   validate_decomposition '[{"title":"...","summary":"...","acceptance":["..."]}]'
#   format_for_creation '[...]' > issues-to-create.json
#
# Or direct invocation:
#   ./decompose.sh --help
#
# Patterns:
#   - Vertical slicing (end-to-end features, not horizontal layers)
#   - Foundation + features (infrastructure first, then independent features)
#   - 1-4 hour sizing per issue
#   - Dependencies declared via "Blocked by #N" format

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Sizing thresholds
MAX_SUBTASKS_PER_ISSUE=5
MAX_ACCEPTANCE_CRITERIA=8

# --- Vertical Slice Examples (for Gemini context) ---
#
# GOOD: Vertical slice decomposition
#   Intent: "We need dark mode"
#   Issue 1: Theme system foundation
#     - CSS variables for colors
#     - Toggle component
#     - LocalStorage persistence
#     All layers (storage + logic + UI) in one issue
#
#   Issue 2: Dark mode for dashboard (blocked by #1)
#     - Update dashboard CSS to use theme variables
#     - Test both light and dark modes
#     End-to-end for one feature area
#
# BAD: Horizontal layer decomposition
#   Issue 1: Add CSS variables (just styling)
#   Issue 2: Add toggle state (just logic)
#   Issue 3: Add localStorage (just storage)
#   Problem: No single issue is shippable, tight coupling
#
# GOOD: Foundation + Features pattern
#   Intent: "Add user authentication"
#   Foundation: Auth infrastructure (JWT, middleware, session)
#   Feature 1: Email/password login (end-to-end)
#   Feature 2: OAuth Google login (end-to-end)
#   Feature 3: Password reset flow (end-to-end)
#   Pattern: Foundation blocks features, features are independent

# --- Functions ---

# Generate a decomposition prompt for Gemini
# Arguments: intent_string
# Returns: Prompt text for Gemini to decompose the intent
generate_decomposition_prompt() {
  local intent="$1"

  if [ -z "$intent" ]; then
    echo "[error] Intent string is required" >&2
    return 1
  fi

  cat <<EOF
Decompose this intent into GitHub issues using vertical slicing:

INTENT: $intent

GUIDELINES:
1. **Sizing:** Each issue should be 1-4 hours of work (S or M size)
2. **Vertical slices:** Each issue includes ALL layers needed (DB + API + UI)
   - NOT horizontal: "Add DB schema" + "Add API" + "Add UI" (bad)
   - YES vertical: "Login flow end-to-end" (good)
3. **Foundation + Features pattern:**
   - First issue is "Foundation" if new infrastructure needed
   - Remaining issues are independent features building on foundation
   - Foundation blocks features, features can run in parallel
4. **Shippable value:** Each issue demonstrates working functionality
5. **Dependencies:** Only foundation->features, avoid feature->feature dependencies

OUTPUT FORMAT (JSON array):
[
  {
    "title": "Brief, actionable title",
    "summary": "1-3 sentences describing what needs to be done",
    "acceptance": [
      "Criterion 1 (testable)",
      "Criterion 2 (testable)"
    ],
    "depends_on": [],
    "complexity": "S|M"
  },
  {
    "title": "Feature built on foundation",
    "summary": "Description of end-to-end feature",
    "acceptance": [
      "Criterion 1",
      "Criterion 2"
    ],
    "depends_on": [1],
    "complexity": "S"
  }
]

CONSTRAINTS:
- Maximum $MAX_SUBTASKS_PER_ISSUE subtasks per issue
- Maximum $MAX_ACCEPTANCE_CRITERIA acceptance criteria per issue
- Each acceptance criterion must be testable/verifiable
- depends_on is array of issue indices (1-based) from this decomposition

Return ONLY the JSON array, no explanation.
EOF
}

# Validate decomposition JSON from Gemini
# Arguments: json_array_string
# Returns: 0 if valid, 1 if invalid (with error messages)
validate_decomposition() {
  local json="$1"
  local errors=0

  if [ -z "$json" ]; then
    echo "[error] JSON input is required" >&2
    return 1
  fi

  # Check if valid JSON
  if ! echo "$json" | jq empty 2>/dev/null; then
    echo "[error] Invalid JSON format" >&2
    return 1
  fi

  # Check if array
  local is_array
  is_array=$(echo "$json" | jq 'type == "array"')
  if [ "$is_array" != "true" ]; then
    echo "[error] Decomposition must be a JSON array" >&2
    return 1
  fi

  # Count issues
  local issue_count
  issue_count=$(echo "$json" | jq 'length')

  if [ "$issue_count" -eq 0 ]; then
    echo "[error] Decomposition is empty" >&2
    return 1
  fi

  # Validate each issue
  local i=0
  while [ $i -lt "$issue_count" ]; do
    local issue
    issue=$(echo "$json" | jq ".[$i]")

    # Check required fields
    local title summary acceptance
    title=$(echo "$issue" | jq -r '.title // empty')
    summary=$(echo "$issue" | jq -r '.summary // empty')
    acceptance=$(echo "$issue" | jq '.acceptance // []')

    if [ -z "$title" ]; then
      echo "[error] Issue $((i+1)): missing title" >&2
      errors=$((errors + 1))
    fi

    if [ -z "$summary" ]; then
      echo "[error] Issue $((i+1)): missing summary" >&2
      errors=$((errors + 1))
    fi

    # Check acceptance criteria count
    local criteria_count
    criteria_count=$(echo "$acceptance" | jq 'length')

    if [ "$criteria_count" -eq 0 ]; then
      echo "[error] Issue $((i+1)): missing acceptance criteria" >&2
      errors=$((errors + 1))
    fi

    if [ "$criteria_count" -gt $MAX_ACCEPTANCE_CRITERIA ]; then
      echo "[warning] Issue $((i+1)): too many acceptance criteria ($criteria_count > $MAX_ACCEPTANCE_CRITERIA)" >&2
      # Not a hard error, just warning
    fi

    # Validate depends_on references
    local depends_on
    depends_on=$(echo "$issue" | jq '.depends_on // []')
    local dep_count
    dep_count=$(echo "$depends_on" | jq 'length')

    local d=0
    while [ $d -lt "$dep_count" ]; do
      local dep
      dep=$(echo "$depends_on" | jq ".[$d]")

      # Check if dependency index is valid (1-based, so must be <= issue_count and > 0)
      if [ "$dep" -lt 1 ] || [ "$dep" -gt "$issue_count" ]; then
        echo "[error] Issue $((i+1)): invalid dependency index $dep" >&2
        errors=$((errors + 1))
      fi

      # Check for self-reference
      if [ "$dep" -eq $((i+1)) ]; then
        echo "[error] Issue $((i+1)): self-dependency detected" >&2
        errors=$((errors + 1))
      fi

      d=$((d + 1))
    done

    i=$((i + 1))
  done

  # Check for circular dependencies using a simple DFS approach
  local cycle_check
  cycle_check=$(check_dependency_cycles "$json")
  if [ -n "$cycle_check" ]; then
    echo "[error] Circular dependency detected: $cycle_check" >&2
    errors=$((errors + 1))
  fi

  if [ $errors -gt 0 ]; then
    echo "[error] Validation failed with $errors errors" >&2
    return 1
  fi

  echo "[ok] Decomposition validated: $issue_count issues" >&2
  return 0
}

# Check for circular dependencies in decomposition
# Arguments: json_array_string
# Returns: Empty if no cycles, otherwise cycle description
check_dependency_cycles() {
  local json="$1"
  local issue_count
  issue_count=$(echo "$json" | jq 'length')

  # Build adjacency list and check with tsort
  local graph=""
  local i=0
  while [ $i -lt "$issue_count" ]; do
    local depends_on
    depends_on=$(echo "$json" | jq -r ".[$i].depends_on // [] | .[]" 2>/dev/null || echo "")

    for dep in $depends_on; do
      # Edge: dep -> i+1 (dependency must complete before this issue)
      graph="${graph}${dep} $((i+1))\n"
    done

    i=$((i + 1))
  done

  # If no dependencies, no cycles possible
  if [ -z "$graph" ]; then
    return 0
  fi

  # Use tsort to detect cycles
  local tsort_result
  tsort_result=$(printf "%b" "$graph" | tsort 2>&1) || {
    # tsort exits non-zero on cycle
    echo "Cycle in dependency graph"
    return 0
  }

  # No cycle detected
  return 0
}

# Format validated decomposition for issue creation
# Arguments: json_array_string [issue_number_offset]
# Returns: JSON array ready for issue-create.sh
# Note: issue_number_offset is used when creating issues to set correct "Blocked by #N" references
format_for_creation() {
  local json="$1"
  local offset="${2:-0}"  # Starting issue number offset (for existing issues)

  if [ -z "$json" ]; then
    echo "[error] JSON input is required" >&2
    return 1
  fi

  local issue_count
  issue_count=$(echo "$json" | jq 'length')

  # Transform each issue to issue-create format
  echo "$json" | jq --argjson offset "$offset" '
    to_entries | map({
      index: (.key + 1),
      title: .value.title,
      body: (
        "## Summary\n" +
        .value.summary + "\n\n" +
        "## Acceptance Criteria\n" +
        (.value.acceptance | map("- [ ] " + .) | join("\n")) + "\n\n" +
        "## Dependencies\n" +
        (if (.value.depends_on | length) > 0 then
          (.value.depends_on | map("Blocked by #" + (. + $offset | tostring)) | join("\n"))
        else
          "None"
        end) + "\n"
      ),
      complexity: (.value.complexity // "M"),
      depends_on: .value.depends_on
    })
  '
}

# Get decomposition as human-readable summary
# Arguments: json_array_string
# Returns: Formatted text summary
format_for_review() {
  local json="$1"

  if [ -z "$json" ]; then
    echo "[error] JSON input is required" >&2
    return 1
  fi

  local issue_count
  issue_count=$(echo "$json" | jq 'length')

  echo "## Decomposition Summary"
  echo ""
  echo "**Issues:** $issue_count"
  echo ""

  local i=0
  while [ $i -lt "$issue_count" ]; do
    local issue
    issue=$(echo "$json" | jq ".[$i]")

    local title summary complexity depends_on
    title=$(echo "$issue" | jq -r '.title')
    summary=$(echo "$issue" | jq -r '.summary')
    complexity=$(echo "$issue" | jq -r '.complexity // "M"')
    depends_on=$(echo "$issue" | jq -r '.depends_on // [] | map("#" + tostring) | join(", ")')

    echo "### Issue $((i+1)): $title"
    echo ""
    echo "**Size:** $complexity"
    if [ -n "$depends_on" ] && [ "$depends_on" != "" ]; then
      echo "**Blocked by:** $depends_on"
    fi
    echo ""
    echo "$summary"
    echo ""

    echo "**Acceptance Criteria:**"
    echo "$issue" | jq -r '.acceptance[] | "- [ ] " + .'
    echo ""

    i=$((i + 1))
  done
}

# --- CLI Interface ---
show_help() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Task decomposition helper for orchestrator.

COMMANDS:
  prompt INTENT     Generate Gemini prompt for decomposing intent
  validate JSON     Validate decomposition JSON
  format JSON       Format decomposition for issue creation
  review JSON       Format decomposition for human review

EXAMPLES:
  # Generate prompt for Gemini
  $(basename "$0") prompt "We need dark mode"

  # Validate decomposition output
  $(basename "$0") validate '[{"title":"...","summary":"...","acceptance":["..."]}]'

  # Format for issue creation
  $(basename "$0") format '[...]' > issues.json

  # Format for CEO review
  $(basename "$0") review '[...]'

FUNCTIONS (when sourced):
  generate_decomposition_prompt INTENT
  validate_decomposition JSON
  format_for_creation JSON [OFFSET]
  format_for_review JSON

EOF
}

# Main CLI handler (when run directly, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    prompt)
      if [ -z "${2:-}" ]; then
        echo "[error] Intent string required" >&2
        echo "Usage: $(basename "$0") prompt \"intent string\"" >&2
        exit 1
      fi
      generate_decomposition_prompt "$2"
      ;;
    validate)
      if [ -z "${2:-}" ]; then
        echo "[error] JSON input required" >&2
        echo "Usage: $(basename "$0") validate 'JSON'" >&2
        exit 1
      fi
      validate_decomposition "$2"
      ;;
    format)
      if [ -z "${2:-}" ]; then
        echo "[error] JSON input required" >&2
        echo "Usage: $(basename "$0") format 'JSON'" >&2
        exit 1
      fi
      format_for_creation "$2" "${3:-0}"
      ;;
    review)
      if [ -z "${2:-}" ]; then
        echo "[error] JSON input required" >&2
        echo "Usage: $(basename "$0") review 'JSON'" >&2
        exit 1
      fi
      format_for_review "$2"
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

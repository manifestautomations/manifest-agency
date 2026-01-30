#!/usr/bin/env bash
# trust-validation.sh - Trust ceiling validation for workspace dispatch
#
# Parses trust ledgers and enforces hierarchical trust constraints.
# Child workspace trust level cannot exceed parent-granted ceiling.
#
# Exported functions:
#   get_current_trust_level - Parse current level from ledger
#   get_trust_ceiling       - Parse trust ceiling from ledger
#   validate_trust_ceiling  - Enforce ceiling constraints
#
# Usage (when sourced):
#   source trust-validation.sh
#   validate_trust_ceiling "$workspace_path" "$parent_ceiling"

# Re-source guard
[[ -n "${_TRUST_VALIDATION_SOURCED:-}" ]] && return 0
_TRUST_VALIDATION_SOURCED=1

_TRUST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TRUST_REPO_ROOT="$(cd "$_TRUST_SCRIPT_DIR/../.." && pwd)"

# Parse current trust level from ledger markdown table
# Args: $1=ledger_path
# Returns: trust level (0-4), defaults to 0 if missing/unparseable
# Table format: | **Current Level** | N (Trust Name) |
get_current_trust_level() {
    local ledger_path="${1:-.planning/trust-ledger.md}"

    # Default to most restrictive level if ledger missing
    if [[ ! -f "$ledger_path" ]]; then
        echo "0"
        return 0
    fi

    # Parse Current Level from table
    local level
    level=$(grep -i "Current Level" "$ledger_path" 2>/dev/null | \
            awk -F'|' '{print $3}' | \
            tr -d ' ' | \
            grep -oE '^[0-4]' | \
            head -1)

    # Default to 0 if parse fails
    if [[ -z "$level" ]]; then
        echo "Warning: Failed to parse current level from $ledger_path" >&2
        echo "0"
        return 0
    fi

    echo "$level"
}

# Parse trust ceiling from ledger markdown table
# Args: $1=ledger_path
# Returns: trust ceiling (0-4), defaults to 4 if missing
# Table format: | **Trust Ceiling** | N (inherited from parent) |
get_trust_ceiling() {
    local ledger_path="${1:-.planning/trust-ledger.md}"

    # Default to max ceiling if ledger missing
    if [[ ! -f "$ledger_path" ]]; then
        echo "4"
        return 0
    fi

    # Parse Trust Ceiling from table
    local ceiling
    ceiling=$(grep -i "Trust Ceiling" "$ledger_path" 2>/dev/null | \
              awk -F'|' '{print $3}' | \
              tr -d ' ' | \
              grep -oE '^[0-4]' | \
              head -1)

    # Default to max ceiling if not found
    if [[ -z "$ceiling" ]]; then
        echo "4"
        return 0
    fi

    echo "$ceiling"
}

# Validate trust ceiling constraints
# Args: $1=workspace_path, $2=parent_ceiling
# Returns: 0 if valid, 1 if ceiling violated
# Side effects: Generates improvement analysis on violation
validate_trust_ceiling() {
    local workspace_path="$1"
    local parent_ceiling="$2"

    # Validate inputs
    if [[ ! -d "$workspace_path" ]]; then
        echo "Error: Workspace path does not exist: $workspace_path" >&2
        return 1
    fi

    if [[ ! "$parent_ceiling" =~ ^[0-4]$ ]]; then
        echo "Error: Invalid parent ceiling: $parent_ceiling" >&2
        return 1
    fi

    local ledger_path="$workspace_path/.planning/trust-ledger.md"

    # Get child workspace metrics
    local child_level
    child_level=$(get_current_trust_level "$ledger_path")

    local child_ceiling
    child_ceiling=$(get_trust_ceiling "$ledger_path")

    # Validation 1: Child ceiling must not exceed parent ceiling (config mismatch)
    if [[ "$child_ceiling" -gt "$parent_ceiling" ]]; then
        echo "Error: Child trust ceiling ($child_ceiling) exceeds parent ceiling ($parent_ceiling)" >&2
        echo "       Ledger: $ledger_path" >&2
        echo "       This indicates a configuration mismatch." >&2
        generate_improvement_analysis "$workspace_path" "$child_level" "$parent_ceiling"
        return 1
    fi

    # Validation 2: Child current level must not exceed parent ceiling (constraint violation)
    if [[ "$child_level" -gt "$parent_ceiling" ]]; then
        echo "Error: Child trust level ($child_level) exceeds parent ceiling ($parent_ceiling)" >&2
        echo "       Workspace: $workspace_path" >&2
        echo "       This workspace has earned trust beyond parent constraints." >&2
        generate_improvement_analysis "$workspace_path" "$child_level" "$parent_ceiling"
        return 1
    fi

    # All validations passed
    return 0
}

# Generate improvement analysis when ceiling is exceeded
# Args: $1=workspace_path, $2=child_level, $3=parent_ceiling
# Side effects: Prints analysis to stderr, attempts to create GitHub issue
generate_improvement_analysis() {
    local workspace_path="$1"
    local child_level="$2"
    local parent_ceiling="$3"

    local workspace_name
    workspace_name=$(basename "$workspace_path")

    echo "" >&2
    echo "========================================" >&2
    echo "IMPROVEMENT ANALYSIS" >&2
    echo "========================================" >&2
    echo "" >&2
    echo "Workspace '$workspace_name' has achieved trust level $child_level," >&2
    echo "exceeding parent ceiling of $parent_ceiling." >&2
    echo "" >&2
    echo "This suggests the child workspace has developed capabilities" >&2
    echo "or patterns that could benefit the parent agency." >&2
    echo "" >&2

    # Compare .claude/ directories
    local parent_claude="$_TRUST_REPO_ROOT/.claude"
    local child_claude="$workspace_path/.claude"

    if [[ -d "$child_claude" ]]; then
        echo "Child workspace assets:" >&2

        local child_agents
        child_agents=$(find "$child_claude/agents" -type f 2>/dev/null | wc -l)
        echo "  - Agents: $child_agents" >&2

        local child_skills
        child_skills=$(find "$child_claude/skills" -type f 2>/dev/null | wc -l)
        echo "  - Skills: $child_skills" >&2

        local child_commands
        child_commands=$(find "$child_claude/commands" -type f 2>/dev/null | wc -l)
        echo "  - Commands: $child_commands" >&2

        if [[ -d "$parent_claude" ]]; then
            local parent_agents
            parent_agents=$(find "$parent_claude/agents" -type f 2>/dev/null | wc -l)

            local parent_skills
            parent_skills=$(find "$parent_claude/skills" -type f 2>/dev/null | wc -l)

            local parent_commands
            parent_commands=$(find "$parent_claude/commands" -type f 2>/dev/null | wc -l)

            echo "" >&2
            echo "Parent agency assets:" >&2
            echo "  - Agents: $parent_agents" >&2
            echo "  - Skills: $parent_skills" >&2
            echo "  - Commands: $parent_commands" >&2
        fi
    fi

    echo "" >&2
    echo "Recommended action:" >&2
    echo "  1. Review child workspace's .claude/ directory" >&2
    echo "  2. Identify unique patterns or capabilities" >&2
    echo "  3. Consider promoting successful patterns to parent" >&2
    echo "  4. Adjust parent ceiling if appropriate" >&2
    echo "" >&2

    # Attempt to create improvement task (best effort)
    _create_improvement_task "$workspace_name" "$child_level" "$parent_ceiling"
}

# Create GitHub issue for improvement tracking (best effort)
# Args: $1=workspace_name, $2=child_level, $3=parent_ceiling
# Side effects: Creates GitHub issue if gh CLI available
_create_improvement_task() {
    local workspace_name="$1"
    local child_level="$2"
    local parent_ceiling="$3"

    # Check for gh CLI
    if ! command -v gh &>/dev/null; then
        echo "Note: gh CLI not available, skipping GitHub issue creation" >&2
        return 0
    fi

    # Check for existing improvement task to prevent duplicates
    local existing
    existing=$(gh issue list --label "trust-system" --search "$workspace_name" 2>/dev/null | grep -i "improvement" | head -1)

    if [[ -n "$existing" ]]; then
        echo "Note: Improvement task already exists for $workspace_name, skipping" >&2
        return 0
    fi

    # Create GitHub issue
    local title="[Improvement] Analyze why $workspace_name outperformed parent"
    local body
    body=$(cat <<EOF
## Context

Workspace \`$workspace_name\` has achieved trust level **$child_level**, exceeding parent ceiling of **$parent_ceiling**.

This indicates the child workspace developed capabilities or demonstrated performance beyond parent expectations.

## Analysis Steps

1. Review child workspace trust ledger: \`$workspace_name/.planning/trust-ledger.md\`
2. Compare session history between parent and child
3. Identify unique .claude/ assets in child workspace:
   \`\`\`bash
   diff -r .claude/ $workspace_name/.claude/
   \`\`\`
4. Review success patterns in child's Active Metrics table

## Actionable Investigation

\`\`\`bash
# List child-specific agents/skills
comm -13 <(ls .claude/agents/ 2>/dev/null | sort) <(ls $workspace_name/.claude/agents/ 2>/dev/null | sort)
comm -13 <(ls .claude/skills/ 2>/dev/null | sort) <(ls $workspace_name/.claude/skills/ 2>/dev/null | sort)

# Review session outcomes
tail -20 $workspace_name/.planning/trust-ledger.md
\`\`\`

## Recommendation

Based on analysis, either:
- **Promote** successful child patterns to parent agency
- **Adjust** parent ceiling if child's performance is validated
- **Document** why child outperformed for future reference

## Labels

\`enhancement\`, \`trust-system\`, \`pending-review\`
EOF
)

    gh issue create --title "$title" --body "$body" \
        --label "enhancement,trust-system,pending-review" 2>/dev/null && \
        echo "Created improvement task: $title" >&2 || \
        echo "Note: Failed to create GitHub issue (this is non-blocking)" >&2

    return 0
}

# Export public functions
export -f get_current_trust_level
export -f get_trust_ceiling
export -f validate_trust_ceiling

# Direct execution mode (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    # Test mode: validate provided workspace
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <workspace_path> <parent_ceiling>" >&2
        exit 1
    fi

    validate_trust_ceiling "$1" "$2"
    exit $?
fi

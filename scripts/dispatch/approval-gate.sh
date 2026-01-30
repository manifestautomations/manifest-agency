#!/usr/bin/env bash
# approval-gate.sh - Cross-workspace approval workflow gate
# Usage: Source this script and call check_approval_requirement before dispatching
#
# Functions:
#   check_existing_approval     - Check if approval already granted
#   check_approval_requirement  - Check if approval needed, create request if so
#
# Exported functions:
#   check_approval_requirement
#   check_existing_approval

# Guard against re-sourcing
[[ -n "${_APPROVAL_GATE_SOURCED:-}" ]] && return 0
_APPROVAL_GATE_SOURCED=1

_APPROVAL_GATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_APPROVAL_GATE_REPO_ROOT="$(cd "$_APPROVAL_GATE_SCRIPT_DIR/../.." && pwd)"

# Get path to approval-workflow.sh
_get_approval_workflow_path() {
    local repo_root="${REPO_ROOT:-$_APPROVAL_GATE_REPO_ROOT}"
    echo "$repo_root/.claude/skills/ceo-dashboard/scripts/approval-workflow.sh"
}

# Check if an existing approval covers this workspace
# Arguments: workspace_id, task_description
# Returns: 0 if valid approval exists, 1 if not found
check_existing_approval() {
    local workspace_id="$1"
    local task_description="$2"

    local approved_dir="$_APPROVAL_GATE_REPO_ROOT/.worker/approvals/approved"

    # Check if approvals directory exists
    if [[ ! -d "$approved_dir" ]]; then
        return 1
    fi

    # Search for approved cross_workspace approvals matching this workspace
    for approval_file in "$approved_dir"/*.json; do
        # Skip if no files match
        [[ -e "$approval_file" ]] || continue

        # Check if approval is for cross_workspace and matches workspace
        local approval_type workspace_match
        approval_type=$(jq -r '.type' "$approval_file" 2>/dev/null || echo "")
        workspace_match=$(jq -r '.context.workspace' "$approval_file" 2>/dev/null || echo "")

        if [[ "$approval_type" == "cross_workspace" ]] && [[ "$workspace_match" == "$workspace_id" ]]; then
            # Valid approval found
            return 0
        fi
    done

    # No matching approval found
    return 1
}

# Check if approval is required and create request if needed
# Arguments: workspace_id, task_description, trust_level
# Returns: 0 if can proceed (no approval needed or already approved), 1 if blocked (approval required)
check_approval_requirement() {
    local workspace_id="$1"
    local task_description="$2"
    local trust_level="$3"

    # Trust level < 3: no approval needed
    if [[ "$trust_level" -lt 3 ]]; then
        return 0
    fi

    # Check if approval already exists
    if check_existing_approval "$workspace_id" "$task_description"; then
        # Approval already granted, proceed
        return 0
    fi

    # Approval required but not yet granted - create approval request
    local approval_workflow_path
    approval_workflow_path=$(_get_approval_workflow_path)

    if [[ ! -f "$approval_workflow_path" ]]; then
        echo "Error: approval-workflow.sh not found at: $approval_workflow_path" >&2
        return 1
    fi

    # Source approval workflow (dynamic sourcing to avoid circular dependencies)
    # shellcheck source=/dev/null
    source "$approval_workflow_path"

    # Build context JSON
    local context_json
    context_json=$(jq -nc \
        --arg workspace "$workspace_id" \
        --arg task "$task_description" \
        --arg level "$trust_level" \
        '{
            workspace: $workspace,
            task: $task,
            trust_level: ($level | tonumber),
            operation_type: "cross_workspace_dispatch"
        }')

    # Create approval request
    local approval_id
    approval_id=$(create_approval_request "cross_workspace" "orchestrator" "$context_json")

    # Print user instructions to stderr
    echo "" >&2
    echo "======================================" >&2
    echo "CROSS-WORKSPACE APPROVAL REQUIRED" >&2
    echo "======================================" >&2
    echo "" >&2
    echo "Trust Level: $trust_level" >&2
    echo "Workspace: $workspace_id" >&2
    echo "Task: $task_description" >&2
    echo "" >&2
    echo "Approval request created: $approval_id" >&2
    echo "Dispatched to CEO inbox for review." >&2
    echo "" >&2
    echo "RESPONSE OPTIONS:" >&2
    echo "  Approve:  Review in inbox and respond with 'approve $approval_id'" >&2
    echo "  Deny:     Respond with 'deny $approval_id'" >&2
    echo "  Modify:   Respond with 'deny $approval_id <reason>' and adjust request" >&2
    echo "  Defer:    Respond with 'defer' to create GitHub issue for later" >&2
    echo "" >&2
    echo "Re-run this command after approval to continue." >&2
    echo "======================================" >&2

    # Return 1 to block dispatch (exit-and-resume pattern)
    return 1
}

# Export functions for sourcing
export -f check_approval_requirement
export -f check_existing_approval

# Execute if run directly (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    # Simple test interface
    case "${1:-}" in
        test-check)
            check_approval_requirement "${2:-test-workspace}" "${3:-test task}" "${4:-3}"
            ;;
        test-existing)
            check_existing_approval "${2:-test-workspace}" "${3:-test task}"
            ;;
        *)
            echo "Usage: $0 {test-check|test-existing} [workspace] [task] [level]" >&2
            exit 1
            ;;
    esac
fi

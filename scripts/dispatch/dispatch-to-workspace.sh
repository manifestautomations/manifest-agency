#!/usr/bin/env bash
# dispatch-to-workspace.sh - Route work to specific workspaces by name
# Usage: ./scripts/dispatch/dispatch-to-workspace.sh <workspace> <task_description> [parent_agent]
#
# Resolves workspace name, checks health, logs dispatch event, records frecency.
#
# Exit codes:
#   0 - Dispatch successful
#   1 - Dispatch failed (workspace not found, RED health declined, etc.)
#
# Exported functions:
#   dispatch_to_workspace - Main dispatch routing function
#   get_target_workspace  - Intelligent target selection with frecency fallback

_DISPATCH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DISPATCH_REPO_ROOT="$(cd "$_DISPATCH_SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$_DISPATCH_REPO_ROOT/.worker/config.json"
DISPATCH_LOG="$_DISPATCH_REPO_ROOT/.worker/dispatch/dispatch.jsonl"

# Source dependencies (using unique variable names to avoid overwrites)
# Note: Source fuzzy-match FIRST since other scripts may overwrite SCRIPT_DIR
source "$_DISPATCH_SCRIPT_DIR/fuzzy-match.sh"
source "$_DISPATCH_SCRIPT_DIR/trust-validation.sh"
source "$_DISPATCH_SCRIPT_DIR/approval-gate.sh"
source "$_DISPATCH_REPO_ROOT/scripts/workspace/workspace-resolve.sh"
source "$_DISPATCH_REPO_ROOT/scripts/workspace/workspace-health.sh"
source "$_DISPATCH_REPO_ROOT/scripts/workspace/workspace-frecency.sh"

# Keep references to repo root available for functions
REPO_ROOT="$_DISPATCH_REPO_ROOT"

# Ensure dispatch log directory exists
mkdir -p "$(dirname "$DISPATCH_LOG")"

# Check if running interactively
_is_interactive() {
    [[ -t 0 ]] && [[ -t 1 ]]
}

# Get trust ceiling from config
# Returns: trust level (integer), defaults to 2 if not found
_get_trust_ceiling() {
    if ! command -v jq &>/dev/null; then
        echo "2"
        return 0
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "2"
        return 0
    fi

    local trust_level
    trust_level=$(jq -r '.guardrails.default_trust_level // 2' "$CONFIG_FILE" 2>/dev/null) || {
        echo "2"
        return 0
    }

    echo "$trust_level"
}

# Generate unique dispatch ID
_generate_dispatch_id() {
    # Use nanoseconds if available, fall back to seconds + random
    if date +%N &>/dev/null 2>&1; then
        echo "workspace-dispatch-$(date +%s%N)-$$"
    else
        echo "workspace-dispatch-$(date +%s)-${RANDOM}-$$"
    fi
}

# Log dispatch event to JSONL
# Args: $1=dispatch_id, $2=workspace_id, $3=workspace_path, $4=parent_agent,
#       $5=trust_ceiling, $6=task_description, $7=health_status,
#       $8=child_trust_level, $9=approval_status, $10=approval_id
_log_dispatch_event() {
    local dispatch_id="$1"
    local workspace_id="$2"
    local workspace_path="$3"
    local parent_agent="$4"
    local trust_ceiling="$5"
    local task_description="$6"
    local health_status="$7"
    local child_trust_level="${8:-0}"
    local approval_status="${9:-not_required}"
    local approval_id="${10:-}"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Escape task description for JSON (handle quotes and special chars)
    local escaped_task
    escaped_task=$(printf '%s' "$task_description" | jq -Rs '.')
    # Remove surrounding quotes from jq output since we'll add them in the template
    escaped_task="${escaped_task:1:-1}"

    # Append JSONL event
    printf '{"timestamp":"%s","event_type":"workspace_dispatch","event_id":"%s","data":{"workspace_id":"%s","workspace_path":"%s","parent_agent":"%s","trust_ceiling":%d,"child_trust_level":%d,"task_description":"%s","health_status":"%s","approval_status":"%s","approval_id":"%s"}}\n' \
        "$timestamp" "$dispatch_id" "$workspace_id" "$workspace_path" "$parent_agent" "$trust_ceiling" "$child_trust_level" "$escaped_task" "$health_status" "$approval_status" "$approval_id" >> "$DISPATCH_LOG"
}

# Intelligent target workspace selection
# Usage: get_target_workspace [explicit_target]
# Returns: workspace name to stdout
#
# If explicit_target provided: returns it directly (caller handles resolution)
# If no explicit target: uses frecency ranking to suggest most frequent workspace
get_target_workspace() {
    local explicit_target="${1:-}"

    # If explicit target provided, return it directly
    if [[ -n "$explicit_target" ]]; then
        echo "$explicit_target"
        return 0
    fi

    # No explicit target - use frecency ranking
    local ranked
    ranked=$(rank_workspaces_by_frecency 2>/dev/null | head -1)

    if [[ -z "$ranked" ]]; then
        # No frecency data available
        return 0
    fi

    # Interactive prompt for confirmation
    if _is_interactive; then
        echo "No target specified. Most frequent: $ranked. Use this? (Y/n)" >&2
        read -r -n 1 response
        echo >&2  # Newline after single char read

        case "$response" in
            [nN])
                return 0
                ;;
            *)
                echo "$ranked"
                return 0
                ;;
        esac
    else
        # Non-interactive: no default, require explicit target
        return 0
    fi
}

# Main dispatch function
# Usage: dispatch_to_workspace <workspace_target> <task_description> [parent_agent]
# Returns: 0 on success, 1 on failure
dispatch_to_workspace() {
    local workspace_target="${1:-}"
    local task_description="${2:-}"
    local parent_agent="${3:-ceo}"

    # Check for jq dependency
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed." >&2
        echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)" >&2
        return 1
    fi

    # Handle empty workspace target
    if [[ -z "$workspace_target" ]]; then
        workspace_target=$(get_target_workspace "")
        if [[ -z "$workspace_target" ]]; then
            echo "Error: No workspace target specified and no frecency default available." >&2
            echo "Usage: dispatch_to_workspace <workspace> <task_description> [parent_agent]" >&2
            return 1
        fi
    fi

    # Validate task description
    if [[ -z "$task_description" ]]; then
        echo "Error: Task description is required." >&2
        return 1
    fi

    # ============================================================
    # Step 1: Resolve workspace name to path
    # ============================================================
    local workspace_path
    workspace_path=$(resolve_workspace "$workspace_target" 2>/dev/null)

    if [[ -z "$workspace_path" ]] || [[ ! -d "$workspace_path" ]]; then
        echo "Workspace '$workspace_target' not found." >&2

        # Get fuzzy suggestions
        local suggestions
        suggestions=$(suggest_workspace "$workspace_target" 2>/dev/null | head -5)

        if [[ -n "$suggestions" ]]; then
            echo "Did you mean:" >&2
            while IFS= read -r suggestion; do
                [[ -n "$suggestion" ]] && echo "  - $suggestion" >&2
            done <<< "$suggestions"
        fi

        return 1
    fi

    local workspace_id
    workspace_id=$(basename "$workspace_path")

    # ============================================================
    # Step 1.5: Validate trust ceiling
    # ============================================================
    local parent_ceiling
    parent_ceiling=$(_get_trust_ceiling)

    if ! validate_trust_ceiling "$workspace_path" "$parent_ceiling"; then
        echo "Dispatch blocked: Trust ceiling constraint violated." >&2
        return 1
    fi

    # ============================================================
    # Step 1.6: Check approval requirement (trust level 3+)
    # ============================================================
    # Get child's trust level for approval check
    local child_ledger="$workspace_path/.planning/trust-ledger.md"
    local child_level
    if [[ -f "$child_ledger" ]]; then
        child_level=$(get_current_trust_level "$child_ledger")
    else
        child_level=0
    fi

    # Check if approval is required and granted
    local current_approval_id=""
    if ! check_approval_requirement "$workspace_id" "$task_description" "$child_level"; then
        # Approval required but not yet granted - exit and await approval
        return 1
    fi

    # Determine approval status for logging
    local approval_status="not_required"
    if [[ "$child_level" -ge 3 ]]; then
        # Trust level 3+, so approval was required
        # If we got here, it was already approved (check_approval_requirement returned 0)
        approval_status="approved"

        # Try to find the approval_id from approved directory
        local approved_dir="$_DISPATCH_REPO_ROOT/.worker/approvals/approved"
        if [[ -d "$approved_dir" ]]; then
            for approval_file in "$approved_dir"/*.json; do
                [[ -e "$approval_file" ]] || continue
                local approval_type workspace_match
                approval_type=$(jq -r '.type' "$approval_file" 2>/dev/null || echo "")
                workspace_match=$(jq -r '.context.workspace' "$approval_file" 2>/dev/null || echo "")
                if [[ "$approval_type" == "cross_workspace" ]] && [[ "$workspace_match" == "$workspace_id" ]]; then
                    current_approval_id=$(jq -r '.approval_id' "$approval_file" 2>/dev/null || echo "")
                    break
                fi
            done
        fi
    fi

    # ============================================================
    # Step 2: Check workspace health
    # ============================================================
    check_workspace_health "$workspace_path"

    local health_status="$HEALTH_STATUS"

    case "$health_status" in
        RED)
            echo "Workspace '$workspace_id' has blocking issues:" >&2
            for issue in "${HEALTH_ISSUES[@]}"; do
                echo "  - $issue" >&2
            done

            if _is_interactive; then
                echo "" >&2
                echo "Proceed anyway? (y/N)" >&2
                read -r -n 1 response
                echo >&2

                case "$response" in
                    [yY])
                        echo "Proceeding with unhealthy workspace..." >&2
                        ;;
                    *)
                        echo "Dispatch cancelled." >&2
                        return 1
                        ;;
                esac
            else
                echo "Non-interactive mode: Cannot dispatch to RED workspace." >&2
                return 1
            fi
            ;;
        YELLOW)
            echo "Warning: Workspace '$workspace_id' has issues:" >&2
            for issue in "${HEALTH_ISSUES[@]}"; do
                echo "  - $issue" >&2
            done
            echo "Proceeding anyway..." >&2
            ;;
        GREEN)
            # All good, proceed silently
            ;;
    esac

    # ============================================================
    # Step 3: Get trust ceiling (from validation)
    # ============================================================
    local trust_ceiling="$parent_ceiling"

    # ============================================================
    # Step 4: Log dispatch event
    # ============================================================
    local dispatch_id
    dispatch_id=$(_generate_dispatch_id)

    _log_dispatch_event "$dispatch_id" "$workspace_id" "$workspace_path" \
        "$parent_agent" "$trust_ceiling" "$task_description" "$health_status" \
        "$child_level" "$approval_status" "${current_approval_id:-}"

    # ============================================================
    # Step 5: Record frecency access
    # ============================================================
    record_workspace_access "$workspace_id"

    # ============================================================
    # Step 6: Output dispatch confirmation
    # ============================================================
    echo "Dispatched to workspace: $workspace_id"
    echo "Path: $workspace_path"
    echo "Task: $task_description"
    echo "Trust ceiling: Level $trust_ceiling"
    echo "Health: $health_status"

    return 0
}

# Export functions for sourcing
export -f dispatch_to_workspace
export -f get_target_workspace

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    dispatch_to_workspace "$@"
fi

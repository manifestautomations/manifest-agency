#!/usr/bin/env bash
# workspace-health.sh - Check health status of workspaces
# Usage: ./scripts/workspace/workspace-health.sh [workspace-name|path]
#
# If no argument: checks all registered workspaces
# If argument: checks single workspace (name or path)
#
# Health Status:
#   GREEN  - Healthy, ready for dispatch
#   YELLOW - Warnings present, can proceed with caution
#   RED    - Blocking issues, cannot dispatch
#
# Exit codes:
#   0 - All checked workspaces are GREEN or YELLOW
#   1 - At least one workspace is RED

set -euo pipefail

# Handle BASH_SOURCE being unset on some platforms
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source dependencies
source "$SCRIPT_DIR/workspace-list.sh" 2>/dev/null || true
source "$SCRIPT_DIR/workspace-resolve.sh" 2>/dev/null || true
source "$SCRIPT_DIR/workspace-validate.sh" 2>/dev/null || true

# Health check status constants
readonly STATUS_GREEN="GREEN"
readonly STATUS_YELLOW="YELLOW"
readonly STATUS_RED="RED"

# Check health of a single workspace
# Args: $1 = absolute workspace path
# Returns: 0 always (use global variables for status)
# Sets: HEALTH_STATUS, HEALTH_ISSUES (array)
check_workspace_health() {
    local workspace_path="${1:-}"

    if [[ -z "$workspace_path" ]]; then
        echo "Error: workspace path required" >&2
        return 1
    fi

    # Resolve to absolute path if relative
    if [[ ! "$workspace_path" = /* ]]; then
        workspace_path="$(cd "$workspace_path" 2>/dev/null && pwd)" || {
            echo "Error: Path '$1' does not exist" >&2
            return 1
        }
    fi

    # Reset health tracking
    HEALTH_STATUS="$STATUS_GREEN"
    HEALTH_ISSUES=()

    local workspace_name
    workspace_name=$(basename "$workspace_path")

    # ============================================================
    # Stage 1: Git state checks
    # ============================================================

    # Check if git repo (using plumbing command)
    if ! git -C "$workspace_path" rev-parse --git-dir >/dev/null 2>&1; then
        HEALTH_STATUS="$STATUS_RED"
        HEALTH_ISSUES+=("Not a git repository")
    else
        # Check for detached HEAD (using plumbing command)
        local head_ref
        head_ref=$(git -C "$workspace_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ "$head_ref" == "HEAD" ]]; then
            if [[ "$HEALTH_STATUS" != "$STATUS_RED" ]]; then
                HEALTH_STATUS="$STATUS_YELLOW"
            fi
            HEALTH_ISSUES+=("Detached HEAD state")
        fi

        # Check for uncommitted changes (using plumbing command)
        # git diff-index returns 1 if there are changes
        if ! git -C "$workspace_path" diff-index --quiet HEAD -- 2>/dev/null; then
            if [[ "$HEALTH_STATUS" != "$STATUS_RED" ]]; then
                HEALTH_STATUS="$STATUS_YELLOW"
            fi
            HEALTH_ISSUES+=("Uncommitted changes present")
        fi

        # Check for untracked files in key directories
        local untracked
        untracked=$(git -C "$workspace_path" ls-files --others --exclude-standard -- src/ lib/ 2>/dev/null | head -1)
        if [[ -n "$untracked" ]]; then
            if [[ "$HEALTH_STATUS" != "$STATUS_RED" ]]; then
                HEALTH_STATUS="$STATUS_YELLOW"
            fi
            HEALTH_ISSUES+=("Untracked files in source directories")
        fi
    fi

    # ============================================================
    # Stage 2: Structure validation
    # ============================================================

    # Check .planning directory
    if [[ ! -d "$workspace_path/.planning" ]]; then
        HEALTH_STATUS="$STATUS_RED"
        HEALTH_ISSUES+=("Missing .planning/ directory")
    fi

    # Check trust ledger (REQUIRED - RED if missing)
    local ledger_path="$workspace_path/.planning/trust-ledger.md"
    if [[ ! -f "$ledger_path" ]]; then
        HEALTH_STATUS="$STATUS_RED"
        HEALTH_ISSUES+=("Missing trust ledger (.planning/trust-ledger.md)")
    fi

    # Check .claude directory (OPTIONAL - YELLOW if missing)
    if [[ ! -d "$workspace_path/.claude" ]]; then
        if [[ "$HEALTH_STATUS" != "$STATUS_RED" ]]; then
            HEALTH_STATUS="$STATUS_YELLOW"
        fi
        HEALTH_ISSUES+=("Missing .claude/ directory (optional)")
    fi

    # ============================================================
    # Stage 3: Trust ledger validity
    # ============================================================

    if [[ -f "$ledger_path" ]]; then
        # Basic format validation - check for required headers
        if ! grep -q "Current Trust Status" "$ledger_path" 2>/dev/null; then
            if [[ "$HEALTH_STATUS" != "$STATUS_RED" ]]; then
                HEALTH_STATUS="$STATUS_YELLOW"
            fi
            HEALTH_ISSUES+=("Trust ledger format: missing 'Current Trust Status' header")
        fi

        if ! grep -q "Current Level" "$ledger_path" 2>/dev/null; then
            if [[ "$HEALTH_STATUS" != "$STATUS_RED" ]]; then
                HEALTH_STATUS="$STATUS_YELLOW"
            fi
            HEALTH_ISSUES+=("Trust ledger format: missing 'Current Level' field")
        fi
    fi

    return 0
}

# Print health status for a single workspace (detailed format)
# Args: $1 = workspace path
print_workspace_health() {
    local workspace_path="${1:-}"
    local workspace_name
    workspace_name=$(basename "$workspace_path")

    check_workspace_health "$workspace_path"

    echo "Workspace: $workspace_name"
    echo "Path: $workspace_path"
    echo "Status: $HEALTH_STATUS"

    if [[ ${#HEALTH_ISSUES[@]} -gt 0 ]]; then
        echo ""
        echo "Issues:"
        for issue in "${HEALTH_ISSUES[@]}"; do
            echo "  - $issue"
        done
    fi
}

# Check all registered workspaces
# Returns: 0 if all GREEN/YELLOW, 1 if any RED
check_all_workspaces() {
    local has_red=false
    local workspace_data=()

    echo "Workspace Health Status"
    echo "======================="
    echo ""

    # Get list of workspaces from workspace-list.sh
    local workspaces_json
    workspaces_json=$(list_workspaces --porcelain 2>/dev/null || echo "[]")

    if [[ "$workspaces_json" == "[]" ]]; then
        echo "No workspaces registered."
        echo ""
        echo "To register workspaces, add them as git submodules:"
        echo "  git submodule add <url> projects/<name>"
        return 0
    fi

    # Parse workspace list and check each
    local name path status
    while IFS= read -r line; do
        name=$(echo "$line" | jq -r '.name')
        path=$(echo "$line" | jq -r '.path')
        status=$(echo "$line" | jq -r '.status')

        local full_path="$REPO_ROOT/$path"

        # Skip if not initialized
        if [[ "$status" == "not-initialized" ]]; then
            printf "[SKIP] %-30s (not initialized)\n" "$name"
            continue
        fi

        # Check health
        check_workspace_health "$full_path"

        # Format output based on status
        case "$HEALTH_STATUS" in
            "$STATUS_GREEN")
                printf "[OK]   %-30s\n" "$name"
                ;;
            "$STATUS_YELLOW")
                local first_issue="${HEALTH_ISSUES[0]:-unknown}"
                printf "[WARN] %-30s %s\n" "$name:" "$first_issue"
                ;;
            "$STATUS_RED")
                has_red=true
                local first_issue="${HEALTH_ISSUES[0]:-unknown}"
                printf "[ERR]  %-30s %s\n" "$name:" "$first_issue"
                ;;
        esac

    done < <(echo "$workspaces_json" | jq -c '.[]')

    echo ""

    # Summary
    if [[ "$has_red" == "true" ]]; then
        echo "Some workspaces have blocking issues (RED status)."
        echo "These workspaces cannot receive dispatched work until fixed."
        return 1
    else
        echo "All workspaces are healthy or have minor warnings."
        return 0
    fi
}

# Main entry point
_workspace_health_main() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        # No argument - check all workspaces
        check_all_workspaces
    else
        # Single workspace specified
        local resolved_path

        # Try to resolve name to path
        if [[ -d "$target" ]]; then
            # Direct path
            resolved_path="$target"
        else
            # Try workspace-resolve.sh
            resolved_path=$(resolve_workspace "$target" 2>/dev/null) || {
                echo "Error: Cannot resolve workspace '$target'" >&2
                echo "Use an absolute path or a registered workspace name." >&2
                return 1
            }
        fi

        print_workspace_health "$resolved_path"

        # Return appropriate exit code
        if [[ "$HEALTH_STATUS" == "$STATUS_RED" ]]; then
            return 1
        fi
    fi
}

# Execute if run directly (not sourced)
(return 0 2>/dev/null) || _workspace_health_main "$@"

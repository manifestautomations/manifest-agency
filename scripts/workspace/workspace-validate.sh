#!/usr/bin/env bash
# workspace-validate.sh - Validate workspace structure
# Usage: ./scripts/workspace/workspace-validate.sh <path>
#
# Validates that a workspace has the required structure:
#   - Is a git repository (.git exists)
#   - Has .planning/trust-ledger.md (required)
#   - Has .claude/ directory (optional, warns if missing)
#
# Exit codes:
#   0 - All required structure present
#   1 - Required structure missing or path doesn't exist

# Handle case where BASH_SOURCE may be unset (bash script.sh invocation on some platforms)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Function that can be sourced by other scripts
# Args: $1 = workspace path
# Returns: 0 on success, 1 on failure
# Outputs: validation results to stdout, errors to stderr
validate_workspace_structure() {
    local workspace_path="${1:-}"

    if [[ -z "$workspace_path" ]]; then
        echo "Usage: workspace-validate.sh <path>" >&2
        return 1
    fi

    # Resolve to absolute path
    if [[ ! "$workspace_path" = /* ]]; then
        workspace_path="$(cd "$workspace_path" 2>/dev/null && pwd)" || {
            echo "Error: Path '$1' does not exist or is not accessible" >&2
            return 1
        }
    fi

    # Check path exists
    if [[ ! -d "$workspace_path" ]]; then
        echo "Error: Path '$workspace_path' does not exist or is not a directory" >&2
        return 1
    fi

    local has_errors=false
    local has_warnings=false
    local issues=()
    local warnings=()

    # Stage 1: Check if git repository (REQUIRED)
    # Using git plumbing command for stable API
    if ! git -C "$workspace_path" rev-parse --git-dir >/dev/null 2>&1; then
        has_errors=true
        issues+=("Not a git repository")
    fi

    # Stage 2: Check .planning directory (REQUIRED)
    if [[ ! -d "$workspace_path/.planning" ]]; then
        has_errors=true
        issues+=("Missing .planning/ directory")
    fi

    # Stage 3: Check trust-ledger.md (REQUIRED)
    local ledger_path="$workspace_path/.planning/trust-ledger.md"
    if [[ ! -f "$ledger_path" ]]; then
        has_errors=true
        issues+=("Missing .planning/trust-ledger.md")
    else
        # Basic format validation - check for required headers
        # Do NOT parse full markdown (too fragile)
        if ! grep -q "Current Trust Status" "$ledger_path" 2>/dev/null; then
            has_warnings=true
            warnings+=("Trust ledger missing 'Current Trust Status' header")
        fi
        if ! grep -q "Current Level" "$ledger_path" 2>/dev/null; then
            has_warnings=true
            warnings+=("Trust ledger missing 'Current Level' field")
        fi
    fi

    # Stage 4: Check .claude directory (OPTIONAL - warn only)
    if [[ ! -d "$workspace_path/.claude" ]]; then
        has_warnings=true
        warnings+=("Missing .claude/ directory (optional)")
    fi

    # Output validation results
    local workspace_name
    workspace_name=$(basename "$workspace_path")

    echo "Validating: $workspace_name"
    echo "Path: $workspace_path"
    echo ""

    if [[ "$has_errors" == "true" ]]; then
        echo "Status: INVALID"
        echo ""
        echo "Required items missing:"
        for issue in "${issues[@]}"; do
            echo "  [ERROR] $issue"
        done
    else
        echo "Status: VALID"
    fi

    if [[ "$has_warnings" == "true" ]]; then
        echo ""
        echo "Warnings:"
        for warning in "${warnings[@]}"; do
            echo "  [WARN] $warning"
        done
    fi

    # Return appropriate exit code
    if [[ "$has_errors" == "true" ]]; then
        return 1
    fi
    return 0
}

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    set -euo pipefail
    validate_workspace_structure "${1:-}"
fi

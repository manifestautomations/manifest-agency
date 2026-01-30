#!/usr/bin/env bash
# workspace-list.sh - List all registered workspaces from .gitmodules
# Usage: ./scripts/workspace/workspace-list.sh [--porcelain]
#
# Source of truth: .gitmodules file (git submodules)
# Uses git config (plumbing command) for stable API
# See: https://git-scm.com/docs/git-submodule

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GITMODULES_FILE="$REPO_ROOT/.gitmodules"

PORCELAIN="${1:-}"

# Function that can be sourced by other scripts
list_workspaces() {
    local porcelain="${1:-}"

    # Check if .gitmodules exists
    if [[ ! -f "$GITMODULES_FILE" ]]; then
        if [[ "$porcelain" == "--porcelain" ]]; then
            echo "[]"
        else
            echo "No workspaces registered (.gitmodules not found)"
        fi
        return 0
    fi

    # Check if any submodules are defined
    local submodule_keys
    submodule_keys=$(git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null) || true
    if [[ -z "$submodule_keys" ]]; then
        if [[ "$porcelain" == "--porcelain" ]]; then
            echo "[]"
        else
            echo "No workspaces registered (no submodules in .gitmodules)"
        fi
        return 0
    fi

    if [[ "$porcelain" == "--porcelain" ]]; then
        # Machine-readable JSON output
        echo "["
        local first=true
        git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' | \
        while read -r key; do
            name=$(echo "$key" | sed 's/^submodule\.\(.*\)\.path$/\1/')
            path=$(git config --file "$GITMODULES_FILE" --get "$key")
            url=$(git config --file "$GITMODULES_FILE" --get "submodule.$name.url" 2>/dev/null || echo "")

            # Check initialization status
            local status="not-initialized"
            if [[ -d "$REPO_ROOT/$path/.git" ]] || [[ -f "$REPO_ROOT/$path/.git" ]]; then
                status="initialized"
            fi

            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '  {"name": "%s", "path": "%s", "url": "%s", "status": "%s"}' "$name" "$path" "$url" "$status"
        done
        echo ""
        echo "]"
    else
        # Human-readable table output
        echo "Registered Workspaces"
        echo "====================="
        echo ""
        printf "%-30s %-35s %-15s\n" "NAME" "PATH" "STATUS"
        printf "%-30s %-35s %-15s\n" "----" "----" "------"

        git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' | \
        while read -r key; do
            name=$(echo "$key" | sed 's/^submodule\.\(.*\)\.path$/\1/')
            path=$(git config --file "$GITMODULES_FILE" --get "$key")

            # Check initialization status
            local status="not initialized"
            if [[ -d "$REPO_ROOT/$path/.git" ]] || [[ -f "$REPO_ROOT/$path/.git" ]]; then
                status="initialized"
            fi

            printf "%-30s %-35s %-15s\n" "$name" "$path" "$status"
        done

        echo ""
        # Count workspaces
        local count
        count=$(git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' | wc -l)
        echo "Total: $count workspace(s)"
    fi
}

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    list_workspaces "$PORCELAIN"
fi

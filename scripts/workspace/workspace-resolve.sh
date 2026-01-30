#!/usr/bin/env bash
# workspace-resolve.sh - Resolve workspace name/alias to filesystem path
# Usage: ./scripts/workspace/workspace-resolve.sh <workspace-name>
#
# Resolution order:
#   1. Exact directory match at projects/<name>/
#   2. Submodule path suffix match from .gitmodules
#   3. Alias lookup from .worker/config.json (case-insensitive)
#
# Exit codes:
#   0 - Success, absolute path printed to stdout
#   1 - Workspace not found, error and suggestions to stderr

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GITMODULES_FILE="$REPO_ROOT/.gitmodules"
CONFIG_FILE="$REPO_ROOT/.worker/config.json"

# Function that can be sourced by other scripts
# Returns 0 on success with path to stdout, 1 on failure with error to stderr
resolve_workspace() {
    local input="${1:-}"

    if [[ -z "$input" ]]; then
        echo "Usage: workspace-resolve.sh <workspace-name>" >&2
        return 1
    fi

    # Get projects directory from config
    local projects_dir="projects"
    if [[ -f "$CONFIG_FILE" ]]; then
        projects_dir=$(jq -r '.workspaces.projects_dir // "projects"' "$CONFIG_FILE")
    fi

    # Resolution 1: Check if exact directory exists at projects/<name>/
    local exact_path="$REPO_ROOT/$projects_dir/$input"
    if [[ -d "$exact_path" ]]; then
        echo "$exact_path"
        return 0
    fi

    # Resolution 2: Check .gitmodules for submodule with matching path suffix
    if [[ -f "$GITMODULES_FILE" ]]; then
        local submodule_keys
        submodule_keys=$(git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null) || true

        if [[ -n "$submodule_keys" ]]; then
            while read -r key; do
                local submodule_path
                submodule_path=$(git config --file "$GITMODULES_FILE" --get "$key")
                local submodule_name
                submodule_name=$(basename "$submodule_path")

                # Case-insensitive comparison
                if [[ "${submodule_name,,}" == "${input,,}" ]]; then
                    echo "$REPO_ROOT/$submodule_path"
                    return 0
                fi
            done <<< "$submodule_keys"
        fi
    fi

    # Resolution 3: Check aliases from config.json (case-insensitive)
    if [[ -f "$CONFIG_FILE" ]]; then
        local aliases_json
        aliases_json=$(jq -c '.workspaces.aliases // []' "$CONFIG_FILE")

        if [[ "$aliases_json" != "[]" ]]; then
            local input_lower="${input,,}"
            local match_path

            # Iterate through aliases
            while IFS= read -r alias_entry; do
                local alias_name
                local alias_path
                alias_name=$(echo "$alias_entry" | jq -r '.alias')
                alias_path=$(echo "$alias_entry" | jq -r '.path')

                # Case-insensitive alias match
                if [[ "${alias_name,,}" == "$input_lower" ]]; then
                    # Resolve relative path to absolute
                    if [[ "$alias_path" == /* ]]; then
                        match_path="$alias_path"
                    else
                        match_path="$REPO_ROOT/$alias_path"
                    fi

                    if [[ -d "$match_path" ]]; then
                        echo "$match_path"
                        return 0
                    else
                        echo "Alias '$input' points to non-existent path: $alias_path" >&2
                        return 1
                    fi
                fi
            done < <(echo "$aliases_json" | jq -c '.[]')
        fi
    fi

    # Not found - print error and list valid workspaces
    echo "Workspace '$input' not found." >&2
    echo "Valid workspaces:" >&2

    # List directories in projects/
    if [[ -d "$REPO_ROOT/$projects_dir" ]]; then
        local has_projects=false
        for dir in "$REPO_ROOT/$projects_dir"/*/; do
            if [[ -d "$dir" ]]; then
                local name
                name=$(basename "$dir")
                # Skip hidden directories and .gitkeep
                if [[ "$name" != .* ]]; then
                    echo "  - $name" >&2
                    has_projects=true
                fi
            fi
        done
    fi

    # List submodules from .gitmodules
    if [[ -f "$GITMODULES_FILE" ]]; then
        local submodule_keys
        submodule_keys=$(git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null) || true

        if [[ -n "$submodule_keys" ]]; then
            while read -r key; do
                local submodule_path
                submodule_path=$(git config --file "$GITMODULES_FILE" --get "$key")
                echo "  - $(basename "$submodule_path") (submodule at $submodule_path)" >&2
            done <<< "$submodule_keys"
        fi
    fi

    # List aliases
    if [[ -f "$CONFIG_FILE" ]]; then
        local aliases_json
        aliases_json=$(jq -c '.workspaces.aliases // []' "$CONFIG_FILE")

        if [[ "$aliases_json" != "[]" ]]; then
            echo "Aliases:" >&2
            echo "$aliases_json" | jq -r '.[] | "  - \(.alias) -> \(.path)"' >&2
        fi
    fi

    return 1
}

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    resolve_workspace "${1:-}"
fi

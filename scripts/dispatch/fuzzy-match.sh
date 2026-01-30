#!/usr/bin/env bash
# fuzzy-match.sh - Fuzzy matching for workspace name suggestions
# Usage: ./scripts/dispatch/fuzzy-match.sh suggest <input>
#
# Provides Levenshtein distance calculation and typo-tolerant workspace suggestions
#
# Commands when run directly:
#   levenshtein <str1> <str2>  - Calculate edit distance between strings
#   suggest <input>            - Suggest workspaces matching input (typo tolerance)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.worker/config.json"
GITMODULES_FILE="$REPO_ROOT/.gitmodules"
PROJECTS_DIR="$REPO_ROOT/projects"

# Suggestion threshold (max edit distance to include)
FUZZY_THRESHOLD=3

# Calculate Levenshtein distance between two strings
# Usage: levenshtein <str1> <str2>
# Returns: edit distance (integer) to stdout
#
# Algorithm: Dynamic programming matrix approach
# Reference: https://en.wikipedia.org/wiki/Levenshtein_distance
levenshtein() {
    local str1="${1:-}"
    local str2="${2:-}"

    # Handle empty strings
    if [[ -z "$str1" ]]; then
        echo "${#str2}"
        return 0
    fi
    if [[ -z "$str2" ]]; then
        echo "${#str1}"
        return 0
    fi

    local len1=${#str1}
    local len2=${#str2}

    # Create distance matrix using associative array
    # d[i,j] = distance between str1[0..i-1] and str2[0..j-1]
    declare -a d

    # Initialize first row (deletions from str1)
    for ((i = 0; i <= len1; i++)); do
        d[i * (len2 + 1)]=$i
    done

    # Initialize first column (insertions into str1)
    for ((j = 0; j <= len2; j++)); do
        d[j]=$j
    done

    # Fill in the rest of the matrix
    for ((i = 1; i <= len1; i++)); do
        for ((j = 1; j <= len2; j++)); do
            local char1="${str1:i-1:1}"
            local char2="${str2:j-1:1}"

            # Cost is 0 if characters match, 1 otherwise
            local cost=1
            if [[ "$char1" == "$char2" ]]; then
                cost=0
            fi

            # Index calculations
            local idx=$((i * (len2 + 1) + j))
            local idx_del=$(((i - 1) * (len2 + 1) + j))      # deletion
            local idx_ins=$((i * (len2 + 1) + (j - 1)))       # insertion
            local idx_sub=$(((i - 1) * (len2 + 1) + (j - 1))) # substitution

            # Take minimum of three operations
            local deletion=$((d[idx_del] + 1))
            local insertion=$((d[idx_ins] + 1))
            local substitution=$((d[idx_sub] + cost))

            # Find minimum
            local min=$deletion
            if [[ $insertion -lt $min ]]; then
                min=$insertion
            fi
            if [[ $substitution -lt $min ]]; then
                min=$substitution
            fi

            d[$idx]=$min
        done
    done

    # Return final distance
    echo "${d[len1 * (len2 + 1) + len2]}"
    return 0
}

# Get all registered workspace names
# Returns: workspace names, one per line
_get_all_workspaces() {
    local workspaces=""

    # 1. Get projects from projects/ directory
    if [[ -d "$PROJECTS_DIR" ]]; then
        for dir in "$PROJECTS_DIR"/*/; do
            if [[ -d "$dir" ]]; then
                local name
                name=$(basename "$dir")
                # Skip hidden directories
                if [[ "$name" != .* ]]; then
                    workspaces+="$name"$'\n'
                fi
            fi
        done
    fi

    # 2. Get submodule names from .gitmodules
    if [[ -f "$GITMODULES_FILE" ]]; then
        local submodule_paths
        submodule_paths=$(git config --file "$GITMODULES_FILE" --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null) || true

        if [[ -n "$submodule_paths" ]]; then
            while read -r key; do
                local submodule_path
                submodule_path=$(git config --file "$GITMODULES_FILE" --get "$key")
                workspaces+="$(basename "$submodule_path")"$'\n'
            done <<< "$submodule_paths"
        fi
    fi

    # 3. Get alias names from .worker/config.json
    if [[ -f "$CONFIG_FILE" ]]; then
        local aliases
        aliases=$(jq -r '.workspaces.aliases[]?.alias // empty' "$CONFIG_FILE" 2>/dev/null) || true
        if [[ -n "$aliases" ]]; then
            workspaces+="$aliases"$'\n'
        fi
    fi

    # Remove duplicates and empty lines, output
    echo "$workspaces" | sort -u | grep -v '^$'
}

# Suggest workspaces matching input (typo-tolerant)
# Usage: suggest_workspace <input>
# Returns: workspace names sorted by edit distance (closest first), one per line
#
# Only includes workspaces within FUZZY_THRESHOLD edit distance
suggest_workspace() {
    local input="${1:-}"

    # Handle empty input
    if [[ -z "$input" ]]; then
        return 0
    fi

    # Convert input to lowercase for case-insensitive matching
    local input_lower="${input,,}"

    # Get all workspaces
    local workspaces
    workspaces=$(_get_all_workspaces)

    if [[ -z "$workspaces" ]]; then
        return 0
    fi

    # Calculate distance for each workspace and collect matches
    local matches=""
    while IFS= read -r ws; do
        [[ -z "$ws" ]] && continue

        # Convert workspace to lowercase for comparison
        local ws_lower="${ws,,}"

        # Calculate edit distance
        local distance
        distance=$(levenshtein "$input_lower" "$ws_lower")

        # Include if within threshold
        if [[ $distance -le $FUZZY_THRESHOLD ]]; then
            matches+="$distance $ws"$'\n'
        fi
    done <<< "$workspaces"

    # Sort by distance ascending and output workspace names only
    if [[ -n "$matches" ]]; then
        echo "$matches" | sort -t' ' -k1 -n | awk '{print $2}' | grep -v '^$'
    fi

    return 0
}

# Export functions for sourcing
export -f levenshtein
export -f suggest_workspace

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail

    case "${1:-}" in
        levenshtein)
            levenshtein "${2:-}" "${3:-}"
            ;;
        suggest)
            suggest_workspace "${2:-}"
            ;;
        *)
            echo "Usage: $0 {levenshtein|suggest} [args]" >&2
            echo "  levenshtein <str1> <str2>  - Calculate edit distance" >&2
            echo "  suggest <input>            - Suggest matching workspaces" >&2
            exit 1
            ;;
    esac
fi

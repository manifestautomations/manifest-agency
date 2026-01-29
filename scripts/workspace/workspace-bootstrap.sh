#!/usr/bin/env bash
# workspace-bootstrap.sh - Bootstrap a new managed workspace
# Usage: ./scripts/workspace/workspace-bootstrap.sh <name> [--path <custom-path>]
#
# Creates a new workspace with:
#   - .planning/ directory with trust ledger
#   - .claude/ directory structure
#   - CLAUDE.md and README.md files
#   - Git repository initialization
#
# The new workspace inherits the parent trust ceiling from .worker/config.json
#
# Exit codes:
#   0 - Workspace bootstrapped successfully
#   1 - Error during bootstrap

set -euo pipefail

# Handle case where BASH_SOURCE may be unset
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the validation script
source "$SCRIPT_DIR/workspace-validate.sh"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "  ${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: workspace-bootstrap.sh <name> [--path <custom-path>]"
    echo ""
    echo "Bootstrap a new managed workspace with isolated trust ledger."
    echo ""
    echo "Arguments:"
    echo "  <name>              Workspace name (used as directory name if no path given)"
    echo ""
    echo "Options:"
    echo "  --path <path>       Custom path for workspace (default: projects/<name>)"
    echo "  --scaffold          Scaffold missing structure in existing directory"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  workspace-bootstrap.sh my-project"
    echo "  workspace-bootstrap.sh my-project --path /path/to/project"
    echo "  workspace-bootstrap.sh my-project --scaffold"
}

# Function to read parent trust ceiling
get_parent_trust_ceiling() {
    local config_path="$REPO_ROOT/.worker/config.json"

    if [[ ! -f "$config_path" ]]; then
        echo "2"  # Default to level 2 if config missing
        return
    fi

    local ceiling
    ceiling=$(jq -r '.guardrails.default_trust_level // 2' "$config_path" 2>/dev/null)

    if [[ -z "$ceiling" || "$ceiling" == "null" ]]; then
        ceiling="2"
    fi

    echo "$ceiling"
}

# Function to substitute placeholders in a file
substitute_placeholders() {
    local file="$1"
    local workspace_name="$2"
    local trust_ceiling="$3"
    local date="$4"

    # Use sed with different delimiter to avoid issues with paths
    sed -i "s|{{WORKSPACE_NAME}}|$workspace_name|g" "$file"
    sed -i "s|{{TRUST_CEILING}}|$trust_ceiling|g" "$file"
    sed -i "s|{{DATE}}|$date|g" "$file"
}

# Function to create directory and report
create_dir() {
    local path="$1"
    local display_name="$2"

    if [[ ! -d "$path" ]]; then
        mkdir -p "$path"
        print_ok "$display_name"
    else
        print_warn "$display_name (already exists)"
    fi
}

# Function to copy and substitute template
copy_template() {
    local template="$1"
    local dest="$2"
    local display_name="$3"
    local workspace_name="$4"
    local trust_ceiling="$5"
    local date="$6"

    if [[ ! -f "$template" ]]; then
        print_error "Template missing: $template"
        return 1
    fi

    if [[ -f "$dest" ]]; then
        print_warn "$display_name (already exists, skipping)"
        return 0
    fi

    cp "$template" "$dest"
    substitute_placeholders "$dest" "$workspace_name" "$trust_ceiling" "$date"
    print_ok "$display_name"
}

# Function to bootstrap a new workspace
bootstrap_workspace() {
    local workspace_name=""
    local custom_path=""
    local scaffold_mode=false

    # Parse arguments - handle --help first before anything else
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_usage
        return 0
    fi

    # First positional arg is workspace name
    workspace_name="${1:-}"
    shift || true

    # Parse remaining arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                custom_path="${2:-}"
                shift 2
                ;;
            --scaffold)
                scaffold_mode=true
                shift
                ;;
            --help|-h)
                show_usage
                return 0
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                show_usage >&2
                return 1
                ;;
        esac
    done

    # Validate workspace name
    if [[ -z "$workspace_name" ]]; then
        echo "Error: Workspace name is required" >&2
        echo ""
        show_usage >&2
        return 1
    fi

    # Validate workspace name format (kebab-case, alphanumeric)
    if ! [[ "$workspace_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        echo "Error: Invalid workspace name '$workspace_name'" >&2
        echo "  Names must start with a letter and contain only letters, numbers, hyphens, underscores" >&2
        return 1
    fi

    # Determine workspace path
    local workspace_path
    if [[ -n "$custom_path" ]]; then
        workspace_path="$custom_path"
    else
        workspace_path="$REPO_ROOT/projects/$workspace_name"
    fi

    # Get parent trust ceiling
    local trust_ceiling
    trust_ceiling=$(get_parent_trust_ceiling)

    # Get current date
    local current_date
    current_date=$(date +%Y-%m-%d)

    # Check templates exist
    local template_dir="$REPO_ROOT/templates/workspace"
    if [[ ! -d "$template_dir" ]]; then
        echo "Error: Template directory not found: $template_dir" >&2
        echo "  Please ensure templates/workspace/ exists with required templates" >&2
        return 1
    fi

    for template in trust-ledger.md CLAUDE.md README.md; do
        if [[ ! -f "$template_dir/$template" ]]; then
            echo "Error: Required template missing: $template_dir/$template" >&2
            return 1
        fi
    done

    # Check if path already exists
    if [[ -d "$workspace_path" ]]; then
        # Check if it's already a valid workspace
        if validate_workspace_structure "$workspace_path" >/dev/null 2>&1; then
            echo "Workspace already exists and is valid: $workspace_path"
            echo ""
            echo "Status: ALREADY_VALID"
            return 0
        fi

        # Exists but invalid - check if we should scaffold
        if [[ "$scaffold_mode" != "true" ]]; then
            echo "Directory exists but is not a valid workspace: $workspace_path"
            echo ""
            echo "Structure incomplete. To scaffold missing components, run:"
            echo "  workspace-bootstrap.sh $workspace_name --scaffold"
            echo ""
            echo "Status: SCAFFOLD_REQUIRED"
            return 1
        fi

        # Path exists with files but no git - abort
        if [[ -n "$(ls -A "$workspace_path" 2>/dev/null)" ]] && \
           ! git -C "$workspace_path" rev-parse --git-dir >/dev/null 2>&1; then
            echo "Error: Directory exists with files but is not a git repository" >&2
            echo "  Path: $workspace_path" >&2
            echo "  Initialize git first: cd '$workspace_path' && git init" >&2
            return 1
        fi
    fi

    # Start bootstrap
    echo "Bootstrapping workspace: $workspace_name"
    echo "Trust ceiling (inherited): Level $trust_ceiling"
    echo ""
    echo "Creating structure..."

    # Create workspace directory if needed
    if [[ ! -d "$workspace_path" ]]; then
        mkdir -p "$workspace_path"
        print_ok "workspace directory"
    fi

    # Create directory structure
    create_dir "$workspace_path/.planning" ".planning/"
    create_dir "$workspace_path/.claude" ".claude/"
    create_dir "$workspace_path/.claude/commands" ".claude/commands/"
    create_dir "$workspace_path/.claude/skills" ".claude/skills/"
    create_dir "$workspace_path/src" "src/"

    echo ""
    echo "Creating files..."

    # Copy and substitute templates
    copy_template "$template_dir/trust-ledger.md" "$workspace_path/.planning/trust-ledger.md" \
        ".planning/trust-ledger.md" "$workspace_name" "$trust_ceiling" "$current_date" || return 1

    copy_template "$template_dir/CLAUDE.md" "$workspace_path/CLAUDE.md" \
        "CLAUDE.md" "$workspace_name" "$trust_ceiling" "$current_date" || return 1

    copy_template "$template_dir/README.md" "$workspace_path/README.md" \
        "README.md" "$workspace_name" "$trust_ceiling" "$current_date" || return 1

    # Initialize git repository if needed
    echo ""
    echo "Initializing git..."

    if ! git -C "$workspace_path" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$workspace_path" init -q
        print_ok "git init"

        # Create initial commit
        git -C "$workspace_path" add -A
        git -C "$workspace_path" commit -q -m "Initial workspace structure

Bootstrapped by Manifest Automations
Trust ceiling: Level $trust_ceiling
"
        print_ok "initial commit"
    else
        print_warn "git repository (already initialized)"
    fi

    # Validate the workspace
    echo ""
    echo "Validating..."

    if validate_workspace_structure "$workspace_path" >/dev/null 2>&1; then
        print_ok "Structure valid"
    else
        print_error "Validation failed after bootstrap"
        echo ""
        echo "Something went wrong. Please check the workspace structure."
        return 1
    fi

    echo ""
    echo "Workspace bootstrapped successfully."
    echo ""
    echo "Next steps:"
    echo "  1. cd $workspace_path"
    echo "  2. Add your code to src/"
    echo "  3. To add as submodule: git submodule add <url> projects/$workspace_name"
    echo ""
    echo "Status: SUCCESS"

    return 0
}

# Execute if run directly (not sourced)
# Use BASH_SOURCE vs $0 comparison for source detection
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    bootstrap_workspace "$@"
fi

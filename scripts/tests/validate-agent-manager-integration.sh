#!/usr/bin/env bash
# validate-agent-manager-integration.sh - Validate Agent Manager integration
# Usage: bash scripts/tests/validate-agent-manager-integration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test counters
PASS=0
FAIL=0

# Color codes (if supported)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors) -ge 8 ]]; then
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)
else
    GREEN=""
    RED=""
    YELLOW=""
    RESET=""
fi

test_result() {
    local name="$1"
    local result="$2"
    local details="${3:-}"

    if [[ "$result" == "pass" ]]; then
        echo "${GREEN}[PASS]${RESET} $name"
        ((PASS++))
    else
        echo "${RED}[FAIL]${RESET} $name"
        if [[ -n "$details" ]]; then
            echo "       ${YELLOW}→${RESET} $details"
        fi
        ((FAIL++))
    fi
}

echo "=== Phase 12: Agent Manager Integration Validation ==="
echo ""

# ============================================================================
# Test Category 1: agents.md Loading Test
# ============================================================================
echo "${YELLOW}[1/5]${RESET} agents.md Loading Test"
echo "-------------------------------------------"

# Test 1.1: agents.md exists
if [[ -f "$REPO_ROOT/.gemini/agents.md" ]]; then
    test_result "agents.md exists" "pass"
else
    test_result "agents.md exists" "fail" "File not found at .gemini/agents.md"
fi

# Test 1.2: Valid markdown structure
if [[ -f "$REPO_ROOT/.gemini/agents.md" ]]; then
    if grep -q "^# " "$REPO_ROOT/.gemini/agents.md" 2>/dev/null; then
        test_result "agents.md has markdown headers" "pass"
    else
        test_result "agents.md has markdown headers" "fail" "No markdown headers found"
    fi
fi

# Test 1.3: Required sections present
if [[ -f "$REPO_ROOT/.gemini/agents.md" ]]; then
    missing_sections=()

    grep -q "## Intent Classification" "$REPO_ROOT/.gemini/agents.md" || missing_sections+=("Intent Classification")
    grep -q "## Workspace Awareness" "$REPO_ROOT/.gemini/agents.md" || missing_sections+=("Workspace Awareness")
    grep -q "## Script Index" "$REPO_ROOT/.gemini/agents.md" || missing_sections+=("Script Index")

    if [[ ${#missing_sections[@]} -eq 0 ]]; then
        test_result "Required sections present" "pass"
    else
        test_result "Required sections present" "fail" "Missing: ${missing_sections[*]}"
    fi
fi

# Test 1.4: Script paths in index are valid
if [[ -f "$REPO_ROOT/.gemini/agents.md" ]]; then
    invalid_scripts=()

    # Extract script paths from the Script Index section
    # Look for patterns like: scripts/orchestrator/dispatch.sh, scripts/portfolio/status.sh
    while IFS= read -r script_path; do
        if [[ -n "$script_path" ]]; then
            full_path="$REPO_ROOT/$script_path"
            if [[ ! -f "$full_path" ]]; then
                invalid_scripts+=("$script_path")
            fi
        fi
    done < <(grep -oP 'scripts/[a-z/-]+\.sh' "$REPO_ROOT/.gemini/agents.md" 2>/dev/null || true)

    if [[ ${#invalid_scripts[@]} -eq 0 ]]; then
        test_result "Script paths valid" "pass"
    else
        test_result "Script paths valid" "fail" "Invalid: ${invalid_scripts[*]}"
    fi
fi

echo ""

# ============================================================================
# Test Category 2: Skill Structure Test
# ============================================================================
echo "${YELLOW}[2/5]${RESET} Skill Structure Test"
echo "-------------------------------------------"

# Test 2.1: Skill directories exist
skills=("status" "briefing" "approve" "dispatch")
missing_skills=()

for skill in "${skills[@]}"; do
    if [[ ! -d "$REPO_ROOT/.gemini/skills/$skill" ]]; then
        missing_skills+=("$skill")
    fi
done

if [[ ${#missing_skills[@]} -eq 0 ]]; then
    test_result "All skill directories exist" "pass"
else
    test_result "All skill directories exist" "fail" "Missing: ${missing_skills[*]}"
fi

# Test 2.2: Each SKILL.md has valid YAML frontmatter
for skill in "${skills[@]}"; do
    skill_file="$REPO_ROOT/.gemini/skills/$skill/SKILL.md"

    if [[ -f "$skill_file" ]]; then
        # Check for YAML frontmatter (starts with ---)
        if head -n 1 "$skill_file" | grep -q "^---"; then
            test_result "SKILL.md for $skill has frontmatter" "pass"
        else
            test_result "SKILL.md for $skill has frontmatter" "fail" "Missing --- delimiter"
        fi
    else
        test_result "SKILL.md for $skill exists" "fail" "File not found"
    fi
done

# Test 2.3: Script references in skills point to existing files
for skill in "${skills[@]}"; do
    skill_file="$REPO_ROOT/.gemini/skills/$skill/SKILL.md"

    if [[ -f "$skill_file" ]]; then
        invalid_refs=()

        # Extract script paths from skill file
        while IFS= read -r script_path; do
            if [[ -n "$script_path" ]]; then
                full_path="$REPO_ROOT/$script_path"
                if [[ ! -f "$full_path" ]]; then
                    invalid_refs+=("$script_path")
                fi
            fi
        done < <(grep -oP 'scripts/[a-z/-]+\.sh' "$skill_file" 2>/dev/null || true)

        if [[ ${#invalid_refs[@]} -eq 0 ]]; then
            test_result "Script refs in $skill are valid" "pass"
        else
            test_result "Script refs in $skill are valid" "fail" "Invalid: ${invalid_refs[*]}"
        fi
    fi
done

echo ""

# ============================================================================
# Test Category 3: Script Execution Test
# ============================================================================
echo "${YELLOW}[3/5]${RESET} Script Execution Test"
echo "-------------------------------------------"

# Test 3.1: Scripts are executable
scripts_to_test=(
    "scripts/orchestrator/aggregate.sh"
    "scripts/orchestrator/dispatch.sh"
    "scripts/portfolio/portfolio-briefing.sh"
    "scripts/portfolio/portfolio-dashboard.sh"
    "scripts/workspace/workspace-resolve.sh"
    "scripts/workspace/workspace-health.sh"
    "scripts/dispatch/trust-validation.sh"
    "scripts/dispatch/approval-gate.sh"
)

for script in "${scripts_to_test[@]}"; do
    full_path="$REPO_ROOT/$script"
    if [[ -f "$full_path" ]]; then
        if [[ -x "$full_path" ]]; then
            test_result "$(basename "$script") is executable" "pass"
        else
            test_result "$(basename "$script") is executable" "fail" "Missing execute permission"
        fi
    else
        test_result "$(basename "$script") exists" "fail" "File not found"
    fi
done

# Test 3.2: aggregate.sh --help works
if [[ -x "$REPO_ROOT/scripts/orchestrator/aggregate.sh" ]]; then
    if "$REPO_ROOT/scripts/orchestrator/aggregate.sh" --help >/dev/null 2>&1; then
        test_result "aggregate.sh --help works" "pass"
    else
        test_result "aggregate.sh --help works" "fail" "Command failed"
    fi
fi

# Test 3.3: portfolio-briefing.sh --help works
if [[ -x "$REPO_ROOT/scripts/portfolio/portfolio-briefing.sh" ]]; then
    if "$REPO_ROOT/scripts/portfolio/portfolio-briefing.sh" --help >/dev/null 2>&1; then
        test_result "portfolio-briefing.sh --help works" "pass"
    else
        test_result "portfolio-briefing.sh --help works" "fail" "Command failed"
    fi
fi

# Test 3.4: workspace-resolve.sh with help
if [[ -x "$REPO_ROOT/scripts/workspace/workspace-resolve.sh" ]]; then
    # Just test that it's sourceable without errors
    if bash -n "$REPO_ROOT/scripts/workspace/workspace-resolve.sh" 2>/dev/null; then
        test_result "workspace-resolve.sh has valid syntax" "pass"
    else
        test_result "workspace-resolve.sh has valid syntax" "fail" "Syntax errors detected"
    fi
fi

echo ""

# ============================================================================
# Test Category 4: Inbox Parsing Test
# ============================================================================
echo "${YELLOW}[4/5]${RESET} Inbox Parsing Test"
echo "-------------------------------------------"

# Test 4.1: Inbox directory exists
if [[ -d "$REPO_ROOT/.worker/inbox" ]]; then
    test_result "Inbox directory exists" "pass"
else
    test_result "Inbox directory exists" "fail" "Directory not found at .worker/inbox"
fi

# Test 4.2: Inbox file format parseable (if files exist)
if [[ -d "$REPO_ROOT/.worker/inbox" ]]; then
    inbox_files=("$REPO_ROOT/.worker/inbox"/*.md)

    if [[ -f "${inbox_files[0]}" ]]; then
        # Test frontmatter extraction on first inbox file
        test_file="${inbox_files[0]}"

        if grep -q "^---" "$test_file" 2>/dev/null; then
            test_result "Inbox files have frontmatter" "pass"
        else
            test_result "Inbox files have frontmatter" "fail" "No frontmatter found"
        fi

        # Test for required fields (type, tier, timestamp)
        frontmatter=$(sed -n '/^---$/,/^---$/p' "$test_file" | grep -v "^---$")

        missing_fields=()
        echo "$frontmatter" | grep -q "^type:" || missing_fields+=("type")
        echo "$frontmatter" | grep -q "^tier:" || missing_fields+=("tier")
        echo "$frontmatter" | grep -q "^timestamp:" || missing_fields+=("timestamp")

        if [[ ${#missing_fields[@]} -eq 0 ]]; then
            test_result "Inbox frontmatter has required fields" "pass"
        else
            test_result "Inbox frontmatter has required fields" "fail" "Missing: ${missing_fields[*]}"
        fi
    else
        test_result "Inbox file parsing test" "pass" "No inbox files to test (empty inbox is valid)"
    fi
fi

echo ""

# ============================================================================
# Test Category 5: Cross-Workspace Flow Test
# ============================================================================
echo "${YELLOW}[5/5]${RESET} Cross-Workspace Flow Test"
echo "-------------------------------------------"

# Test 5.1: workspace-resolve.sh is sourceable
if [[ -f "$REPO_ROOT/scripts/workspace/workspace-resolve.sh" ]]; then
    if (source "$REPO_ROOT/scripts/workspace/workspace-resolve.sh" 2>/dev/null); then
        test_result "workspace-resolve.sh is sourceable" "pass"
    else
        test_result "workspace-resolve.sh is sourceable" "fail" "Source command failed"
    fi
fi

# Test 5.2: workspace-health.sh returns valid status
if [[ -x "$REPO_ROOT/scripts/workspace/workspace-health.sh" ]]; then
    # Run health check on current workspace (should be valid)
    health_output=$("$REPO_ROOT/scripts/workspace/workspace-health.sh" "$REPO_ROOT" 2>/dev/null || echo "FAILED")

    if echo "$health_output" | grep -qE "(GREEN|YELLOW|RED)"; then
        test_result "workspace-health.sh returns valid status" "pass"
    else
        test_result "workspace-health.sh returns valid status" "fail" "No status code in output"
    fi
fi

# Test 5.3: trust-validation.sh is sourceable and has exports
if [[ -f "$REPO_ROOT/scripts/dispatch/trust-validation.sh" ]]; then
    if bash -n "$REPO_ROOT/scripts/dispatch/trust-validation.sh" 2>/dev/null; then
        test_result "trust-validation.sh has valid syntax" "pass"
    else
        test_result "trust-validation.sh has valid syntax" "fail" "Syntax errors detected"
    fi

    # Check for exported functions
    if grep -q "^validate_trust_ceiling()" "$REPO_ROOT/scripts/dispatch/trust-validation.sh"; then
        test_result "trust-validation.sh has validate_trust_ceiling" "pass"
    else
        test_result "trust-validation.sh has validate_trust_ceiling" "fail" "Function not found"
    fi
fi

# Test 5.4: approval-gate.sh is sourceable and has exports
if [[ -f "$REPO_ROOT/scripts/dispatch/approval-gate.sh" ]]; then
    if bash -n "$REPO_ROOT/scripts/dispatch/approval-gate.sh" 2>/dev/null; then
        test_result "approval-gate.sh has valid syntax" "pass"
    else
        test_result "approval-gate.sh has valid syntax" "fail" "Syntax errors detected"
    fi

    # Check for exported functions
    if grep -qE "^(check_approval|require_approval)\(\)" "$REPO_ROOT/scripts/dispatch/approval-gate.sh"; then
        test_result "approval-gate.sh has required functions" "pass"
    else
        test_result "approval-gate.sh has required functions" "fail" "Functions not found"
    fi
fi

# Test 5.5: .gitmodules exists (for workspace registration)
if [[ -f "$REPO_ROOT/.gitmodules" ]]; then
    test_result ".gitmodules exists for workspace registration" "pass"
else
    test_result ".gitmodules exists for workspace registration" "fail" "File not found (no workspaces registered)"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=== Validation Summary ==="
echo "Passed: ${GREEN}$PASS${RESET}"
echo "Failed: ${RED}$FAIL${RESET}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo "${GREEN}✓ All integration tests passed${RESET}"
    exit 0
else
    echo "${RED}✗ Some integration tests failed${RESET}"
    echo "Review failures above and fix integration issues."
    exit 1
fi

# Testing Patterns

**Analysis Date:** 2026-01-31

## Test Framework

**Runner:**
- Custom bash test validation scripts
- No dedicated test framework (no Jest, Vitest, Mocha, or similar)
- Tests are shell scripts using `set -euo pipefail` for error handling

**Primary Test File:**
- `scripts/tests/validate-agent-manager-integration.sh` - Comprehensive integration validation
- `test-validator.sh` - Simple validator testing script

**Run Commands:**
```bash
bash scripts/tests/validate-agent-manager-integration.sh  # Run all integration tests
bash test-validator.sh                                    # Run validator test
./scripts/worker/execute.sh --issue N --status            # Check execution status
```

**No Assertion Library:**
Tests use native bash conditionals and return codes for assertions

## Test File Organization

**Location:**
- `scripts/tests/` - Integration and acceptance tests
- `scripts/*/` - Individual script tests and utilities
- Root: `test-validator.sh` - Quick validation test

**Naming:**
- Pattern: `validate-*.sh` or `test-*.sh`
- Test categories in naming: `validate-agent-manager-integration.sh`

**Structure:**
```
scripts/
├── tests/
│   ├── validate-agent-manager-integration.sh    # Full integration test suite
│   └── validate-*.sh
├── worker/
│   ├── execute.sh
│   ├── spawn-subagent.sh
│   └── lib/
│       ├── scope-validator.sh
│       └── timeout-manager.sh
├── orchestrator/
│   ├── decompose.sh
│   └── aggregate.sh
└── dispatch/
    ├── approval-gate.sh
    └── trust-validation.sh

test-validator.sh                               # Root test script
```

## Test Structure

**Suite Organization:**

From `validate-agent-manager-integration.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Color setup (if terminal supports)
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

# Test result helper
test_result() {
    local name="$1"
    local result="$2"
    local details="${3:-}"

    if [[ "$result" == "pass" ]]; then
        echo "${GREEN}[PASS]${RESET} $name"
        PASS=$((PASS + 1))
    else
        echo "${RED}[FAIL]${RESET} $name"
        if [[ -n "$details" ]]; then
            echo "       ${YELLOW}→${RESET} $details"
        fi
        FAIL=$((FAIL + 1))
    fi
}

# Test section with banner
echo "=== Phase 12: Agent Manager Integration Validation ==="
echo ""

echo "${YELLOW}[1/5]${RESET} Test Category 1 Name"
echo "-------------------------------------------"

# Individual tests
if [[ -f "$REPO_ROOT/file.md" ]]; then
    test_result "File exists" "pass"
else
    test_result "File exists" "fail" "File not found at path"
fi
```

**Patterns:**
- Counter variables: `PASS=0` and `FAIL=0` track results
- Test helper function: `test_result()` with name, pass/fail, and optional details
- Colored output: GREEN for pass, RED for fail, YELLOW for info (if terminal supports)
- Test sections: Numbered with headers and separator lines
- Detailed error messages: Include what was expected vs what was found

## Mocking

**Framework:** No formal mocking library

**Patterns:**

From `test-validator.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source scripts/worker/lib/scope-validator.sh

REPO_ROOT=$(pwd)
file1="$REPO_ROOT/.worker/test/agent1/constraints.json"
file2="$REPO_ROOT/.worker/test/agent2/constraints.json"

# Test setup with fixture files
files_json=$(jq -nc --arg f1 "$file1" --arg f2 "$file2" '[$f1, $f2]')

# Invoke function with test data
if detect_write_conflicts "$files_json" 2>&1; then
  echo "Result: NO CONFLICT (returned 0)"
  exit 1
else
  echo "Result: CONFLICT DETECTED (returned 1) - PASS"
  exit 0
fi
```

**Approaches:**
- Fixture files in `.worker/test/` directory structure
- Function invocation with test parameters
- Exit code assertions: `if command 2>&1; then ... else ... fi`
- No stubbing: Real functions are called with test data

**What to Mock:**
- External commands: Use conditional checks (`if command -v git &>/dev/null`)
- File operations: Use test fixtures in `.worker/test/` directory
- GitHub API calls: Use `gh` CLI when available, fail gracefully when not

**What NOT to Mock:**
- Core library functions: Call actual implementations from `lib/` files
- Validation logic: Run real validator functions to test behavior
- Lock operations: Use actual lock file system

## Fixtures and Factories

**Test Data:**
From `test-validator.sh`:
```bash
# Create fixture file paths
REPO_ROOT=$(pwd)
file1="$REPO_ROOT/.worker/test/agent1/constraints.json"
file2="$REPO_ROOT/.worker/test/agent2/constraints.json"

# Build JSON fixture
files_json=$(jq -nc --arg f1 "$file1" --arg f2 "$file2" '[$f1, $f2]')
```

**Location:**
- Test fixtures: `.worker/test/` directory structure
- Constraint files: `.worker/test/agent1/constraints.json`, `.worker/test/agent2/constraints.json`
- Approval files: `.worker/approvals/approved/approval-*.json`, `.worker/approvals/pending/approval-*.json`
- Cache files: `.worker/cache/dashboard-cache.json`, `.worker/cache/portfolio-cache.json`

**Fixture Creation:**
Test scripts create JSON fixtures using `jq -nc` for static test data setup

## Coverage

**Requirements:** Not enforced. No coverage tools detected in codebase.

**View Coverage:** Not applicable - no code coverage measurement in place.

**Test Categories:**
1. **Unit Tests (implicit):** Individual function validation in library scripts
2. **Integration Tests:** `validate-agent-manager-integration.sh` - End-to-end workflow tests
3. **Acceptance Tests:** Manual execution tests with `--status` flag for verification

## Test Types

**Unit Tests:**
- Scope: Individual bash functions in library files
- Approach: Direct function invocation with test parameters
- Location: Within library files or dedicated test scripts
- Example: `validate_command()`, `acquire_lock()` tested through script invocation

**Integration Tests:**
- Scope: Multi-component workflows (agents, skills, workspace)
- Approach: Run full validation suites checking multiple components
- Location: `scripts/tests/validate-agent-manager-integration.sh`
- Test categories in that file:
  1. agents.md loading and structure
  2. Skill structure and files
  3. Agent configuration validation
  4. Script path validity
  5. Integration workflow validation

**E2E Tests:**
- Framework: Manual testing with `./scripts/worker/execute.sh`
- Verification: Using `--status` flag to check execution state
- Approach: Real GitHub issue processing, lock management, PR creation
- No automated E2E test framework present

## Common Patterns

**Async Testing:**
Not applicable - bash scripts are synchronous. Parallelization tested through:
- Graph parsing validation (`lib/graph-parser.sh`)
- Wave execution testing in parallel worker spawning
- Subagent timeout management (`scripts/worker/lib/timeout-manager.sh`)

**Error Testing:**

From `validate-agent-manager-integration.sh`:

```bash
# Test error condition - file doesn't exist
if [[ ! -f "$REPO_ROOT/.gemini/agents.md" ]]; then
    test_result "agents.md exists" "fail" "File not found at .gemini/agents.md"
fi

# Test missing sections
missing_sections=()
grep -q "## Intent Classification" "$REPO_ROOT/.gemini/agents.md" || missing_sections+=("Intent Classification")

if [[ ${#missing_sections[@]} -eq 0 ]]; then
    test_result "Required sections present" "pass"
else
    test_result "Required sections present" "fail" "Missing: ${missing_sections[*]}"
fi

# Test invalid entries
invalid_scripts=()
while IFS= read -r script_path; do
    if [[ -n "$script_path" ]]; then
        full_path="$REPO_ROOT/$script_path"
        if [[ ! -f "$full_path" ]]; then
            invalid_scripts+=("$script_path")
        fi
    fi
done

if [[ ${#invalid_scripts[@]} -eq 0 ]]; then
    test_result "Script paths valid" "pass"
else
    test_result "Script paths valid" "fail" "Invalid: ${invalid_scripts[*]}"
fi
```

**Patterns:**
- Existence checks: `[[ -f "$path" ]]` or `[[ -d "$path" ]]`
- Content validation: `grep -q "pattern" "$file"`
- Array collection: Accumulate failures in arrays, report all at once
- Detailed failure messages: Include specific invalid entries

**Return Code Testing:**

From `test-validator.sh`:

```bash
if detect_write_conflicts "$files_json" 2>&1; then
  echo "Result: NO CONFLICT (returned 0)"
  exit 1
else
  echo "Result: CONFLICT DETECTED (returned 1) - PASS"
  exit 0
fi
```

**Pattern:**
- Assert exit code: `if command ... ; then expect_success; else expect_failure; fi`
- Invert expectations when needed (test failure should succeed)

## Test Statistics

**Total Test Files:** 2 active test scripts
- `scripts/tests/validate-agent-manager-integration.sh` (120+ lines)
- `test-validator.sh` (24 lines)

**Test Density:**
- Integration test file covers 5 major categories with 10+ sub-tests
- No unit test framework or systematic test organization
- Testing is verification-focused rather than coverage-focused

## Validation Strategy

**Pre-Execution Validation:**

Scripts use validator library (`lib/validator.sh`) for:
- Command validation against safety floor patterns
- Scope enforcement (read/write access checks)
- Trust level checks before execution
- Violation recording and tracking

**Audit Trail Testing:**

From `lib/audit.sh`:
```bash
# Validate audit chain integrity
# Returns: 0 if chain is valid, 1 if broken
verify_audit_chain() {
  # Checks:
  # - Chain initialization
  # - Entry integrity (checksums match)
  # - Chain state consistency
  # - Entry count accuracy
}
```

Pattern: Cryptographic validation of immutable audit logs

---

*Testing analysis: 2026-01-31*

# Testing Patterns

**Analysis Date:** 2026-01-29

## Test Framework

**Runner:**
- Shell script testing: Manual bash execution with `set -euo pipefail`
- Validation scripts: `test-validator.sh` for core logic verification
- GitHub integration tests: Via live GitHub API calls in CI context
- Framework: Custom bash-based validation (not a traditional test runner)

**Test Configuration:**
- Location: `test-validator.sh` in project root
- Execution: Direct bash script invocation
- Validation approach: Functional testing with real state checks

**Run Commands:**
```bash
# Run validation tests
bash test-validator.sh                    # Run all tests
bash test-validator.sh --dry-run          # Show what would be tested (if supported)
bash test-validator.sh <specific-test>    # Run specific test
```

## Test File Organization

**Location:**
- Integration tests: `.worker/test/` directory for agent testing
- Validator scripts: Root level as `test-validator.sh`
- Shell library tests: Implicit via skill execution
- No separate test directories; tests are validation-focused

**Structure of test-validator.sh:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Source libraries to test
source scripts/worker/lib/scope-validator.sh

# Build test data
files_json=$(jq -nc --arg f1 "$file1" --arg f2 "$file2" '[$f1, $f2]')

# Run test and check result
if detect_write_conflicts "$files_json" 2>&1; then
  echo "Result: NO CONFLICT (returned 0)"
  exit 1
else
  echo "Result: CONFLICT DETECTED (returned 1) - PASS"
  exit 0
fi
```

## Test Structure

**Suite Organization:**
- Tests are organized by concern: locking, parsing, validation, logging
- Each shell library has implicit tests via skill execution
- Test data created inline or sourced from `.worker/` directories

**Test Patterns:**

1. **Direct Function Testing:**
   ```bash
   # Source the library
   source .claude/skills/worker/lib/parser.sh

   # Set up test data
   ISSUE_BODY="## Summary\nTest summary\n## Acceptance Criteria\n- Test criteria"

   # Call function
   RESULT=$(extract_section "Summary")

   # Assert
   if [ "$RESULT" = "Test summary" ]; then
     echo "PASS: extract_section works"
   else
     echo "FAIL: extract_section returned '$RESULT'"
     exit 1
   fi
   ```

2. **State-Based Testing:**
   Test locking behavior by creating actual lock directories and checking behavior:
   ```bash
   # Acquire lock
   if acquire_lock 42; then
     # Check that lock directory exists
     if [ -d ".worker/locks/issue-42.lock" ]; then
       echo "PASS: Lock acquired"
     else
       echo "FAIL: Lock directory not created"
     fi
     release_lock
   else
     echo "FAIL: Could not acquire lock"
   fi
   ```

3. **Error Condition Testing:**
   ```bash
   # Test behavior with invalid input
   if parse_issue_body 99999; then
     echo "FAIL: Should return error for non-existent issue"
     exit 1
   else
     echo "PASS: Correctly returned error"
   fi
   ```

## Mocking

**Framework:** Minimal - primarily use real state or dummy data

**Patterns:**

1. **Dummy Data Construction:**
   ```bash
   # Create test JSON data inline
   test_data=$(jq -nc \
     --arg title "Test Issue" \
     --arg summary "Test summary" \
     '{title: $title, summary: $summary}'
   )
   ```

2. **GitHub API Mocking:**
   - Use `gh issue view` against actual test issues in test repos
   - No mock framework; tests rely on real GitHub state
   - Example from execution flow: Issue #42 is typically used for testing

3. **File System Mocking:**
   - Use `.worker/test/` directory for test agent configs
   - Create actual JSON files for constraint validation
   - Example from `test-validator.sh`:
     ```bash
     file1="$REPO_ROOT/.worker/test/agent1/constraints.json"
     file2="$REPO_ROOT/.worker/test/agent2/constraints.json"
     ```

**What to Mock:**
- GitHub API responses: Use jq with test data when avoiding API calls
- Timestamp generation: Not mocked; tests use actual timestamps
- File system operations: Use real directories in `.worker/test/`

**What NOT to Mock:**
- Lock acquisition: Must test actual atomic locking behavior
- JSON parsing: Use real jq (too complex to mock)
- Shell command execution: Use real `bash` execution
- GitHub state: Prefer real API calls for integration tests

## Fixtures and Factories

**Test Data:**

1. **JSON Fixtures:**
   ```bash
   # Create test approval data
   approvals_json=$(jq -nc '[
     {type: "approval", agent_id: "agent-1", time_remaining: 3600, stale_status: "active"},
     {type: "approval", agent_id: "agent-2", time_remaining: 300, stale_status: "stale"}
   ]')

   # Test rendering function
   render_pending_approvals "$approvals_json"
   ```

2. **Lock Metadata:**
   ```bash
   # Create test lock metadata
   jq -nc \
     --arg issue "42" \
     --arg pid "12345" \
     --arg started "2026-01-29T15:00:00Z" \
     --arg hostname "test-machine" \
     '{issue: $issue, pid: $pid, started: $started, hostname: $hostname}' \
     > ".worker/locks/issue-42.lock/metadata.json"
   ```

3. **Issue Bodies:**
   Text fixture created inline for parser testing:
   ```bash
   ISSUE_BODY="## Summary
   This is a test summary

   ## Context
   Test context here

   ## Acceptance Criteria
   - [ ] First criterion
   - [ ] Second criterion"
   ```

**Location:**
- Inline in test scripts (no separate fixture files)
- Under `.worker/test/` for persistent test data (e.g., agent configs)
- GitHub issues for integration tests (issue #42 commonly used)

## Coverage

**Requirements:** None enforced

**View Coverage:**
- Manual inspection of test execution results
- No automated coverage reporting
- Tests are ad-hoc validation, not comprehensive coverage

**Gap Analysis:**
- No systematic coverage tracking
- Critical paths tested manually before deployment:
  - Lock acquisition and staleness detection
  - GitHub issue parsing
  - JSON event logging
  - Error handling and signal interruption

## Test Types

**Unit Tests:**
- Scope: Individual shell functions
- Approach: Source library, call function with test data, check return value
- Example: Testing `extract_section()` from `parser.sh` with various input formats
- Run: Direct bash invocation

**Integration Tests:**
- Scope: Multi-function workflows (lock acquisition → execution → release)
- Approach: Execute workflow via skill command, verify state changes
- Example: Full worker execution cycle (plan → approval → execute → complete)
- Run: Via `claude --skill worker:execute --issue N`

**E2E Tests:**
- Framework: GitHub issue → PR creation workflow
- Implementation: Manual via GitHub UI or via GitHub API
- Verification: Check PR exists, issue labeled, comments posted
- No automated E2E framework; rely on manual execution in CI context

**Validation Scripts:**
- Purpose: Verify core invariants before deployment
- Example: `test-validator.sh` checks conflict detection logic
- Run: Pre-deployment validation step

## Common Patterns

**Async Testing:**

Bash doesn't have native async, but worker execution is inherently async:

```bash
# Start worker in background
claude --skill worker:execute --issue 42 &
WORKER_PID=$!

# Wait for planning phase
sleep 5

# Check issue status
if gh issue view 42 --json labels -q '.labels[] | select(.name == "worker:planning")' | grep -q . ; then
  echo "PASS: Planning label set"
else
  echo "FAIL: Planning label not set"
fi

# Clean up
wait $WORKER_PID
```

**Testing Locking Behavior:**
```bash
# Test concurrent lock attempts
acquire_lock 42 &
LOCK_PID=$!

sleep 1

# This should fail due to existing lock
if acquire_lock 42 false 2>&1 | grep -q "Worker already running"; then
  echo "PASS: Lock prevents concurrent execution"
else
  echo "FAIL: Lock did not prevent concurrent execution"
fi

# Clean up first lock
kill $LOCK_PID 2>/dev/null || true
release_lock
```

**Error Testing:**

Testing failure paths by checking return codes:

```bash
# Test parse failure with missing sections
test_issue_body="No proper sections here"
ISSUE_BODY="$test_issue_body"

if validate_issue_for_worker; then
  echo "FAIL: Should reject invalid issue"
  exit 1
else
  echo "PASS: Correctly rejected invalid issue"
fi
```

Testing error messages to stderr:

```bash
# Capture stderr
error_output=$(acquire_lock 99999 false 2>&1) || true

if echo "$error_output" | grep -q "Worker already running"; then
  echo "PASS: Error message is descriptive"
else
  echo "FAIL: Error message not found"
fi
```

**Testing State Machines:**

Verify state transitions in worker execution:

```bash
# Initial state: no labels
gh issue edit 42 --remove-label "worker:planning" 2>/dev/null || true
gh issue edit 42 --remove-label "worker:executing" 2>/dev/null || true

# Run planning
claude --skill worker:execute --issue 42

# Check state
LABELS=$(gh issue view 42 --json labels -q '.labels[].name' | tr '\n' ' ')

if echo "$LABELS" | grep -q "worker:awaiting-approval"; then
  echo "PASS: Transitioned to awaiting-approval state"
else
  echo "FAIL: Expected awaiting-approval label, got: $LABELS"
fi
```

## Manual Testing Approach

Since there's no automated test framework, testing relies on manual verification:

1. **Pre-Deployment:**
   - Run `test-validator.sh` to verify core logic
   - Execute skill workflows manually with test issues
   - Check GitHub state (labels, comments, PRs)

2. **During Development:**
   - Source libraries in bash shell: `source .claude/skills/worker/lib/logger.sh`
   - Call functions interactively: `log_event "test_event" --arg data "test"`
   - Inspect output files: `cat .worker/logs/issue-*.jsonl | jq`

3. **Verification Checklist:**
   - Locks acquired and released correctly
   - Issue parsing extracts correct sections
   - GitHub API calls succeed and fail gracefully
   - JSON logging produces valid JSONL format
   - State transitions occur in correct order
   - Error messages are descriptive and logged

## Testing Workflow in Phase Execution

Phase execution documents define "must_haves" which serve as acceptance tests:

```yaml
must_haves:
  artifacts:
    - path: ".gitmodules"
      provides: "Submodule registry (empty initially)"
      contains: "# Git submodules registry"
  key_links:
    - from: "git config"
      to: "submodule.recurse"
      via: "local git config"
      pattern: "submodule.recurse.*true"
```

Verification of these artifacts:
```bash
# Check file exists with content
if grep -q "# Git submodules registry" .gitmodules; then
  echo "PASS: .gitmodules artifact verified"
fi

# Check git config
if git config --local submodule.recurse | grep -q "true"; then
  echo "PASS: submodule.recurse configured"
fi
```

## Shell Library Testing

**Testing `logger.sh`:**
```bash
source .claude/skills/worker/lib/logger.sh

init_logging 42
log_event "test_event" --arg key1 "value1" --arg key2 "value2"

# Verify log file created
if [ -f "$LOG_FILE" ]; then
  echo "PASS: Log file created"

  # Verify JSONL format
  if jq . "$LOG_FILE" > /dev/null 2>&1; then
    echo "PASS: Log file contains valid JSON"
  fi
fi
```

**Testing `lock.sh`:**
```bash
source .claude/skills/worker/lib/lock.sh

if acquire_lock 42; then
  # Lock acquired
  if [ -d ".worker/locks/issue-42.lock" ] && [ -f ".worker/locks/issue-42.lock/metadata.json" ]; then
    echo "PASS: Lock structure correct"
  fi
  release_lock
fi
```

**Testing `parser.sh`:**
```bash
source .claude/skills/worker/lib/parser.sh

# Set test issue body
ISSUE_BODY="## Summary
Test summary content

## Acceptance Criteria
- Test criteria 1
- Test criteria 2"

# Extract section
SUMMARY=$(extract_section "Summary")
if [ "$SUMMARY" = "Test summary content" ]; then
  echo "PASS: extract_section correct"
fi
```

---

*Testing analysis: 2026-01-29*

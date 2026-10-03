# Phase 3: Single Worker - Research

**Researched:** 2026-01-27
**Domain:** Bash workflow orchestration with state management
**Confidence:** HIGH

<research_summary>
## Summary

Researched how to build a Claude Code skill that orchestrates a multi-step worker workflow: parse GitHub issue → plan execution → get approval → execute in worktree → report results. This is fundamentally a shell scripting task that integrates existing infrastructure from Phases 1-2 rather than a library integration task.

The standard approach uses bash scripts with structured JSON logging (via jq), file-based lock mechanisms (via flock or mkdir), signal handling (via trap), and gh CLI for GitHub operations. The existing infrastructure provides all necessary building blocks: worktree management scripts, GitHub integration scripts, and issue templates.

Key finding: Don't hand-roll state persistence, lock file management, or JSON logging. Use atomic operations (flock for locks, mkdir for directories), jq for JSON generation, and trap for cleanup. The worker skill becomes a coordinator that invokes existing scripts rather than reimplementing their logic.

**Primary recommendation:** Build worker skill as a state machine coordinator that delegates to existing Phase 1-2 scripts, uses lock files for concurrency control, logs everything as JSON events, and reports milestones to GitHub via issue comments.
</research_summary>

<standard_stack>
## Standard Stack

### Core Tools
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 5.x | Worker orchestration script | Universal shell scripting, trap/signal handling |
| jq | 1.8.1 | JSON generation and querying | Handles escaping, produces valid single-line JSON |
| flock | util-linux | Lock file management | Kernel-guaranteed atomic operations |
| gh CLI | 2.x | GitHub API interactions | Official GitHub tool, already used in Phase 2 |
| git | 2.x | Worktree and branch operations | Core version control, already used in Phase 1 |

### Supporting Tools
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| date | coreutils | Timestamps (ISO8601, Unix epoch) | Logging, duration calculation, lock staleness |
| trap | bash builtin | Signal handling and cleanup | Graceful shutdown, lock removal on crash |
| mkdir | coreutils | Atomic directory creation | Alternative to flock for simple locks |
| mktemp | coreutils | Temporary file creation | Session IDs, intermediate data |

### Existing Infrastructure (from Phases 1-2)
| Script | Purpose | Reuse Pattern |
|--------|---------|---------------|
| scripts/worktree-create.sh | Create isolated worktree | Call with issue/{N} branch name |
| scripts/worktree-remove.sh | Remove worktree after PR | Call after PR merge or abort |
| scripts/github/issue-comment.sh | Post progress updates | Call for Plan/Start/Complete comments |
| scripts/github/issue-update-status.sh | Update issue status | Call to transition worker:ready → worker:executing |
| scripts/github/pr-create.sh | Create PR with metadata | Call at completion with agent/duration data |
| templates/github/issue-body.md | Structured issue format | Parse to extract Objective/Requirements |

**Installation:**
```bash
# All tools already available in MINGW64 environment
# Verify:
jq --version          # jq-1.8.1 confirmed
gh --version          # gh CLI 2.x
git --version         # git 2.x
flock --version       # util-linux flock
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```
.claude/
├── skills/
│   └── worker/
│       ├── execute.md           # Main worker skill (orchestrator)
│       ├── lib/
│       │   ├── logger.sh        # JSON logging functions
│       │   ├── lock.sh          # Lock file operations
│       │   └── parser.sh        # Issue body parsing
│       └── templates/
│           ├── plan-comment.md
│           ├── start-comment.md
│           └── complete-comment.md
.worker/
├── logs/                        # gitignored - JSON log files
├── locks/                       # gitignored - Active lock files
├── config.json                  # Committed - Worker configuration
└── .gitkeep                     # Preserves directory structure
```

### Pattern 1: State Machine with Lock Files
**What:** Worker lifecycle modeled as explicit states with atomic lock file transitions
**When to use:** Preventing concurrent execution, detecting crashes
**Example:**
```bash
# Source: Linux flock man page + bash best practices
LOCK_FILE=".worker/locks/issue-${ISSUE_NUMBER}.lock"

# Atomic lock acquisition
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    # Check for stale lock (30 minute threshold)
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ "$LOCK_AGE" -gt 1800 ]; then
        echo "[error] Stale lock detected (${LOCK_AGE}s old)"
        echo "Use --force to override or --inspect to view crash state"
        exit 1
    else
        echo "[error] Worker already running for issue #${ISSUE_NUMBER}"
        exit 1
    fi
fi

# Critical section - worker execution
trap 'flock -u 200; rm -f "$LOCK_FILE"' EXIT SIGTERM SIGINT

# State transitions via labels
gh issue edit "$ISSUE_NUMBER" --add-label "worker:planning"
# ... work ...
gh issue edit "$ISSUE_NUMBER" --remove-label "worker:planning" --add-label "worker:executing"
```

### Pattern 2: Structured JSON Logging
**What:** Every worker event emitted as single-line JSON with consistent schema
**When to use:** All logging - lifecycle, git operations, GitHub API calls, errors
**Example:**
```bash
# Source: https://stegard.net/2021/07/how-to-make-a-shell-script-log-json-messages/
LOG_FILE=".worker/logs/issue-${ISSUE_NUMBER}-$(date +%s).jsonl"
SESSION_ID=$(uuidgen 2>/dev/null || echo "session-$(date +%s)-$$")

log_event() {
    local event_type="$1"
    shift

    jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg event_type "$event_type" \
        --arg event_id "$(uuidgen 2>/dev/null || echo "evt-$$-$(date +%s%N)")" \
        --arg session_id "$SESSION_ID" \
        --argjson data "$(jq -n "$@")" \
        '{
            timestamp: $timestamp,
            event_type: $event_type,
            event_id: $event_id,
            session_id: $session_id,
            data: $data
        }' >> "$LOG_FILE"
}

# Usage examples
log_event "session_start" \
    --arg issue "$ISSUE_NUMBER" \
    --arg agent "claude-worker"

log_event "worktree_created" \
    --arg path "$WORKTREE_PATH" \
    --arg branch "$BRANCH_NAME"

log_event "error" \
    --arg message "Failed to parse issue body" \
    --arg exit_code "$?"
```

### Pattern 3: Milestone-Based GitHub Reporting
**What:** Post only 3 comments to GitHub: Plan → Start → Complete/Failure
**When to use:** Keeping issue threads readable while providing full context
**Example:**
```bash
# Source: Existing scripts/github/issue-comment.sh pattern
post_plan_comment() {
    local issue="$1"
    local plan_summary="$2"
    local base_sha="$3"

    local comment_body="## 🤖 Execution Plan

$plan_summary

**Based on:** \`main @ ${base_sha:0:7}\`

**Next:** React with 👍 to approve execution

<!-- agent:metadata
status: awaiting_approval
agent: claude-worker
plan_generated_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
-->"

    scripts/github/issue-comment.sh "$issue" --message "$comment_body"
    gh issue edit "$issue" --add-label "worker:awaiting-approval"
}

post_complete_comment() {
    local issue="$1"
    local pr_number="$2"
    local duration="$3"

    local comment_body="## ✓ Work Complete

Created PR #${pr_number}

<details>
<summary>Execution Summary</summary>

**Duration:** $duration
**Tasks completed:** $(cat .worker/task-count.txt)
**Commits:** 1

See full execution log with \`claude --skill worker:execute --status $issue\`
</details>

<!-- agent:metadata
status: complete
agent: claude-worker
completed_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
-->"

    scripts/github/issue-comment.sh "$issue" --message "$comment_body"
}
```

### Pattern 4: Crash Detection and Recovery
**What:** Detect incomplete sessions via stale locks + missing session_end event
**When to use:** Allowing human-directed recovery from worker crashes
**Example:**
```bash
# Source: Lock file patterns + log analysis
detect_crash() {
    local issue="$1"
    local lock_file=".worker/locks/issue-${issue}.lock"
    local log_pattern=".worker/logs/issue-${issue}-*.jsonl"

    # Stale lock exists?
    if [ -f "$lock_file" ]; then
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_file") ))

        if [ "$lock_age" -gt 1800 ]; then
            # Check if log has session_end event
            local latest_log=$(ls -t $log_pattern 2>/dev/null | head -1)

            if [ -n "$latest_log" ] && ! grep -q '"event_type":"session_end"' "$latest_log"; then
                echo "[worker] Crash detected for issue #${issue}"
                echo ""
                echo "Recovery options:"
                echo "  --inspect   View crash state (worktree, logs)"
                echo "  --resume    Continue from last checkpoint"
                echo "  --restart   Discard partial work and start fresh"
                return 0  # Crash detected
            fi
        fi
    fi

    return 1  # No crash
}
```

### Pattern 5: Signal Handling for Graceful Shutdown
**What:** Use trap to handle SIGTERM/SIGINT and perform cleanup
**When to use:** Ensuring locks released and state saved on interruption
**Example:**
```bash
# Source: https://mywiki.wooledge.org/SignalTrap
cleanup_on_exit() {
    local exit_code=$?

    log_event "session_interrupted" \
        --arg exit_code "$exit_code" \
        --arg signal "${TRAPPED_SIGNAL:-NONE}"

    # Release lock
    if [ -n "$LOCK_FD" ]; then
        flock -u "$LOCK_FD"
        rm -f "$LOCK_FILE"
    fi

    # Post failure comment if mid-execution
    if [ "$WORKER_STATE" = "executing" ]; then
        post_failure_comment "$ISSUE_NUMBER" "Worker interrupted by signal"
    fi

    exit "$exit_code"
}

# Set up trap handlers
trap 'TRAPPED_SIGNAL=SIGTERM; cleanup_on_exit' SIGTERM
trap 'TRAPPED_SIGNAL=SIGINT; cleanup_on_exit' SIGINT
trap 'cleanup_on_exit' EXIT
```

### Anti-Patterns to Avoid
- **Ad-hoc lock files without staleness detection:** Leads to stuck workers requiring manual cleanup
- **JSON logging with manual string concatenation:** Produces invalid JSON with unescaped quotes, newlines
- **Posting every task as GitHub comment:** Creates unreadable issue threads with 50+ comments
- **Re-implementing worktree/issue operations:** Duplicates Phase 1-2 scripts, introduces bugs
- **Not using trap for cleanup:** Leaves stale locks and uncommitted changes on Ctrl+C
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Lock file atomicity | Manual file existence checks + write | flock or atomic mkdir | Race conditions between check and create; flock kernel-guaranteed |
| JSON generation | String concatenation with manual escaping | jq -n with --arg flags | Unescaped quotes/newlines break JSON; jq handles all edge cases |
| Issue body parsing | Custom regex or awk parsing | Structured templates + grep/sed | Templates ensure consistent format; regex fragile to formatting |
| Worktree creation | Direct git worktree commands | scripts/worktree-create.sh | Sibling naming, safety checks, branch validation already implemented |
| GitHub issue updates | Direct gh api graphql calls | scripts/github/issue-*.sh | Field caching, error handling, retry logic already implemented |
| Signal handling | Manual exit on error | trap EXIT SIGTERM SIGINT | Cleanup not guaranteed; trap ensures cleanup even on kill |
| Timestamp formatting | date with custom formats | date -u +"%Y-%m-%dT%H:%M:%SZ" | ISO8601 standard, UTC prevents timezone bugs |
| Session/event IDs | Random numbers or timestamps | uuidgen or mktemp | Collisions with parallel workers; UUID guarantees uniqueness |

**Key insight:** Shell scripting has 40+ years of solved problems. flock provides kernel-guaranteed atomicity. jq handles JSON escaping correctly every time. trap ensures cleanup even on crashes. The existing Phase 1-2 scripts are 800+ lines of battle-tested logic - reuse them rather than reimplementing.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Lock File Race Conditions
**What goes wrong:** Two workers check for lock, both see none, both create lock, both execute
**Why it happens:** Non-atomic check-then-create operations allow race window
**How to avoid:** Use flock with -n (non-blocking) or atomic mkdir - kernel ensures only one succeeds
**Warning signs:** Multiple workers executing same issue, duplicate PRs, conflicting worktrees

### Pitfall 2: Unescaped JSON Breaking Logs
**What goes wrong:** Error messages with quotes/newlines corrupt JSON log file, jq fails to parse
**Why it happens:** Manual string building doesn't escape special characters
**How to avoid:** Always use jq -n with --arg for variable substitution - jq handles escaping
**Warning signs:** jq parse errors when reading logs, malformed JSON lines, missing log entries

### Pitfall 3: Stale Locks After Crashes
**What goes wrong:** Worker crashes, lock file persists, subsequent runs blocked forever
**Why it happens:** Lock not removed on abnormal exit, no staleness detection
**How to avoid:** Use trap EXIT to remove lock, check lock file mtime for staleness threshold
**Warning signs:** "Worker already running" error when no worker active, old lock files in .worker/locks/

### Pitfall 4: Missing Session End Events
**What goes wrong:** Cannot distinguish clean exit from crash - unclear if work completed
**Why it happens:** Log session_start but exit before log session_end
**How to avoid:** Use trap EXIT to always log final event, check for session_end in crash detection
**Warning signs:** Logs have session_start but no session_end, unclear worker status

### Pitfall 5: GitHub API Rate Limit Exhaustion
**What goes wrong:** Worker hits 5000 API calls/hour limit, subsequent operations fail
**Why it happens:** Not reusing cached data, making redundant API calls in loops
**How to avoid:** Load .cache/github/project-fields.json once, cache issue data, batch label operations
**Warning signs:** gh CLI returning 403 Forbidden, rate limit errors in logs, slow operations

### Pitfall 6: Worktree Paths with Spaces
**What goes wrong:** Script errors with "command not found" or "no such file" on worktree operations
**Why it happens:** Unquoted variable expansion splits on spaces
**How to avoid:** Always quote path variables: "$WORKTREE_PATH", not $WORKTREE_PATH
**Warning signs:** Works on test-branch but fails on issue/42-add-user-auth branch

### Pitfall 7: No Timeout on Blocking Operations
**What goes wrong:** Worker hangs indefinitely on network failure or frozen command
**Why it happens:** gh CLI or git command waits forever for response
**How to avoid:** Use timeout command with 10 minute default, log warning at 80% threshold
**Warning signs:** Worker appears stuck, no log events for extended period, manual kill required

### Pitfall 8: Incomplete Cleanup on Approval Timeout
**What goes wrong:** Worker exits after posting plan but leaves issue in worker:awaiting-approval state
**Why it happens:** Clean exit removes lock but doesn't reset issue state
**How to avoid:** Cleanup function checks current state and resets labels appropriately
**Warning signs:** Issues stuck in awaiting-approval after worker exits, orphaned labels
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from official sources and existing scripts:

### Lock File Acquisition with Staleness Detection
```bash
# Source: https://linux.die.net/man/1/flock + project patterns
acquire_lock() {
    local issue="$1"
    local force="${2:-false}"

    LOCK_FILE=".worker/locks/issue-${issue}.lock"

    # Create locks directory if needed
    mkdir -p "$(dirname "$LOCK_FILE")"

    # Open lock file descriptor
    exec 200>"$LOCK_FILE"

    # Try non-blocking lock
    if ! flock -n 200; then
        # Lock held - check staleness
        local lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
        local threshold=1800  # 30 minutes

        if [ "$lock_age" -gt "$threshold" ] && [ "$force" = "true" ]; then
            echo "[worker] Forcing stale lock (${lock_age}s old)"
            flock -u 200 2>/dev/null || true
            rm -f "$LOCK_FILE"
            exec 200>"$LOCK_FILE"
            flock -n 200 || { echo "[error] Failed to acquire lock after force"; exit 1; }
        elif [ "$lock_age" -gt "$threshold" ]; then
            echo "[error] Stale lock detected (${lock_age}s old)"
            echo "Use --force to override"
            exit 1
        else
            echo "[error] Worker already running for issue #${issue}"
            exit 1
        fi
    fi

    # Lock acquired - set up cleanup
    trap 'flock -u 200; rm -f "$LOCK_FILE"' EXIT

    echo "[worker] Lock acquired: $LOCK_FILE"
}
```

### Structured JSON Event Logging
```bash
# Source: https://stegard.net/2021/07/how-to-make-a-shell-script-log-json-messages/
init_logging() {
    local issue="$1"

    LOG_FILE=".worker/logs/issue-${issue}-$(date +%s).jsonl"
    SESSION_ID="session-$(uuidgen 2>/dev/null || echo "$$-$(date +%s)")"

    mkdir -p "$(dirname "$LOG_FILE")"

    log_event "session_start" \
        --arg issue "$issue" \
        --arg agent "claude-worker" \
        --arg pwd "$PWD"
}

log_event() {
    local event_type="$1"
    shift

    # Build data object from --arg pairs
    local data_json
    data_json=$(jq -n "$@")

    # Emit structured event
    jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg event_type "$event_type" \
        --arg event_id "evt-$(date +%s%N)-$$" \
        --arg session_id "$SESSION_ID" \
        --argjson data "$data_json" \
        '{
            timestamp: $timestamp,
            event_type: $event_type,
            event_id: $event_id,
            session_id: $session_id,
            data: $data
        }' >> "$LOG_FILE"
}

# Usage examples
log_event "worktree_created" \
    --arg path "../manifest-automations-issue-42" \
    --arg branch "issue/42"

log_event "github_api_call" \
    --arg operation "issue_comment" \
    --arg issue "42" \
    --argjson response '{"id": 123, "url": "https://..."}'

log_event "error" \
    --arg message "Failed to parse issue body" \
    --arg phase "planning" \
    --arg exit_code "1"
```

### Issue Body Parsing with Sections
```bash
# Source: Existing templates/github/issue-body.md structure
parse_issue_body() {
    local issue="$1"

    # Fetch issue body
    local body
    body=$(gh issue view "$issue" --json body -q '.body')

    # Extract sections (assumes ## Section headers)
    OBJECTIVE=$(echo "$body" | sed -n '/## Objective/,/## /p' | sed '1d;$d' | sed 's/^[[:space:]]*//')
    REQUIREMENTS=$(echo "$body" | sed -n '/## Requirements/,/## /p' | sed '1d;$d' | sed 's/^[[:space:]]*//')
    ACCEPTANCE=$(echo "$body" | sed -n '/## Acceptance Criteria/,/## /p' | sed '1d;$d' | sed 's/^[[:space:]]*//')

    # Validate required sections
    if [ -z "$OBJECTIVE" ]; then
        log_event "error" --arg message "Issue missing Objective section"
        echo "[error] Issue #$issue missing required section: Objective"
        exit 1
    fi

    log_event "issue_parsed" \
        --arg objective "$OBJECTIVE" \
        --arg requirements "$REQUIREMENTS" \
        --arg acceptance "$ACCEPTANCE"
}
```

### Approval Waiting Pattern
```bash
# Source: GitHub reactions API + project patterns
wait_for_approval() {
    local issue="$1"
    local comment_id="$2"

    log_event "awaiting_approval" \
        --arg issue "$issue" \
        --arg comment_id "$comment_id"

    # Set label and exit cleanly - human re-runs after approval
    gh issue edit "$issue" \
        --remove-label "worker:planning" \
        --add-label "worker:awaiting-approval"

    echo ""
    echo "[worker] Plan posted to issue #${issue}"
    echo "[worker] Waiting for approval..."
    echo ""
    echo "Next steps:"
    echo "  1. Review plan in issue comment"
    echo "  2. React with 👍 to approve"
    echo "  3. Re-run: claude --skill worker:execute --issue $issue"
    echo ""

    log_event "session_end" --arg reason "awaiting_approval"
    exit 0
}

check_approval() {
    local issue="$1"

    # Check for worker:awaiting-approval label
    local labels
    labels=$(gh issue view "$issue" --json labels -q '.labels[].name')

    if echo "$labels" | grep -q "worker:awaiting-approval"; then
        echo "[worker] Approval check..."

        # Check for 👍 reaction on plan comment
        # (Simplified - actual implementation would fetch comment reactions)
        local approved
        approved=$(gh api "/repos/{owner}/{repo}/issues/$issue/comments" \
            --jq '.[] | select(.body | contains("Execution Plan")) | .reactions."+1"')

        if [ "$approved" -gt 0 ]; then
            echo "[worker] ✓ Approval received"
            gh issue edit "$issue" \
                --remove-label "worker:awaiting-approval" \
                --add-label "worker:executing"
            return 0
        else
            echo "[error] Plan not yet approved"
            echo "React with 👍 on the Execution Plan comment to proceed"
            exit 1
        fi
    fi

    return 0  # No approval needed (fresh execution)
}
```

### Duration Calculation
```bash
# Source: Standard Unix timestamp arithmetic
START_TIME=$(date +%s)

# ... work happens ...

calculate_duration() {
    local start="$1"
    local end="$(date +%s)"
    local seconds=$((end - start))
    local minutes=$((seconds / 60))

    if [ "$minutes" -lt 60 ]; then
        echo "${minutes}min"
    else
        local hours=$((minutes / 60))
        local remainder=$((minutes % 60))
        echo "${hours}h ${remainder}min"
    fi
}

DURATION=$(calculate_duration "$START_TIME")
```

### Graceful Shutdown with Trap
```bash
# Source: https://www.geeksforgeeks.org/linux-unix/shell-scripting-bash-trap-command/
setup_signal_handlers() {
    trap 'handle_signal SIGTERM' SIGTERM
    trap 'handle_signal SIGINT' SIGINT
    trap 'handle_exit' EXIT
}

handle_signal() {
    local signal="$1"

    log_event "signal_received" --arg signal "$signal"

    echo ""
    echo "[worker] Received $signal - shutting down gracefully..."

    # If mid-execution, post failure comment
    if [ "${WORKER_STATE:-}" = "executing" ]; then
        post_failure_comment "$ISSUE_NUMBER" "Worker interrupted by $signal"
    fi

    # Cleanup will happen in handle_exit via EXIT trap
    exit 130
}

handle_exit() {
    local exit_code=$?

    log_event "session_end" \
        --arg exit_code "$exit_code" \
        --arg state "${WORKER_STATE:-unknown}"

    # Release lock (trap from acquire_lock does this)
    echo "[worker] Cleanup complete"
}
```
</code_examples>

<sota_updates>
## State of the Art (2024-2025)

What's current in 2026:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JSON logging with echo | jq -n with --arg/--argjson | 2021+ | jq ensures valid JSON, no manual escaping |
| Lock files with touch/rm | flock with file descriptors | 2020+ | Kernel-guaranteed atomicity, no race conditions |
| GitHub API v3 REST | gh CLI + GraphQL | 2023+ | gh CLI handles auth, GraphQL more efficient for project fields |
| Manual signal handling | trap with EXIT/SIGTERM/SIGINT | Always standard | Ensures cleanup even on abnormal exit |
| Subprocess PID tracking | flock exclusive locks | 2020+ | Survives process death, cross-session detection |

**Current tools in 2026:**
- **jq 1.8.1**: Now includes --rawfile for file reading, --exit-status for error handling
- **gh CLI 2.x**: Native project field support, reaction APIs, improved GraphQL templates
- **bash 5.x**: $EPOCHREALTIME for microsecond timestamps (vs POSIX date)

**Deprecated/outdated:**
- **Lockfiles with PID files**: Use flock instead - handles stale locks, survives crashes
- **JSON logging with printf**: Use jq - handles all escaping, prevents malformed JSON
- **Direct GraphQL queries**: Use gh CLI wrappers when available - handles auth, retries
</sota_updates>

<open_questions>
## Open Questions

Things that couldn't be fully resolved:

1. **Approval detection mechanism**
   - What we know: GitHub reactions API exists, can detect 👍 on comments
   - What's unclear: Best UX for re-running after approval - should worker poll? Should human re-run?
   - Recommendation: Use manual re-run pattern (post plan, exit, human approves, human re-runs). Simple, no polling, clear human control. Document in CONTEXT.md decision.

2. **Worktree cleanup timing**
   - What we know: scripts/worktree-remove.sh can remove worktree, PR merge detected via gh pr view
   - What's unclear: Should worker auto-cleanup after PR merge? Or leave for Phase 4 automation?
   - Recommendation: Manual cleanup in Phase 3 (worker posts PR, human merges, human runs cleanup). Automation deferred to Phase 4 per CONTEXT.md.

3. **Log file retention policy**
   - What we know: Logs are gitignored, stored in .worker/logs/
   - What's unclear: How long to keep logs? Max log size? Rotation policy?
   - Recommendation: No automatic cleanup in Phase 3 - logs are gitignored so don't affect repo. Add retention policy in Phase 4 if needed.

4. **Parallel task execution within worker**
   - What we know: CONTEXT.md specifies worker executes tasks sequentially
   - What's unclear: Should worker support task-level parallelism (e.g., independent file edits)?
   - Recommendation: Sequential execution only in Phase 3 - fail fast, clear state. Parallelism deferred per CONTEXT.md decisions.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- Existing Phase 1 scripts: scripts/worktree-*.sh (271 lines, verified in 01-VERIFICATION.md)
- Existing Phase 2 scripts: scripts/github/*.sh (1,800+ lines, verified in 02-VERIFICATION.md)
- flock(1) man page: https://linux.die.net/man/1/flock - kernel-guaranteed atomic locks
- Bash Signal Trap documentation: https://mywiki.wooledge.org/SignalTrap - official bash wiki

### Secondary (MEDIUM confidence)
- [Using Lock Files for Job Control in Bash Scripts](https://www.putorius.net/lock-files-bash-scripts.html) - flock patterns verified
- [How to make a shell script log JSON-messages](https://stegard.net/2021/07/how-to-make-a-shell-script-log-json-messages/) - jq logging verified with official jq docs
- [Handling Signals in Bash Script](https://www.baeldung.com/linux/bash-signal-handling) - trap patterns verified
- [Bash Trap Command Explained](https://phoenixnap.com/kb/bash-trap-command) - cleanup patterns verified

### Tertiary (LOW confidence - needs validation)
- None - all findings verified against official documentation or existing codebase

</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: Bash scripting with jq, flock, trap
- Ecosystem: gh CLI (already integrated), git worktrees (already scripted)
- Patterns: State machines, JSON logging, lock files, signal handling
- Pitfalls: Race conditions, JSON escaping, stale locks, cleanup

**Confidence breakdown:**
- Standard stack: HIGH - all tools already in use or standard Unix utilities
- Architecture: HIGH - patterns verified in existing Phase 1-2 scripts and official documentation
- Pitfalls: HIGH - derived from lock file man pages, JSON logging best practices
- Code examples: HIGH - adapted from official sources and existing project scripts

**Research date:** 2026-01-27
**Valid until:** 2026-02-27 (30 days - bash/Unix patterns are stable)
</metadata>

---

*Phase: 03-single-worker*
*Research completed: 2026-01-27*
*Ready for planning: yes*

# Phase 3 Plan 02: Worker Core Libraries Summary

**One-liner:** JSON logging via jq, atomic mkdir-based locking, and section-parsing issue body extraction

---

## Frontmatter

```yaml
phase: 03-single-worker
plan: 02
subsystem: worker-infrastructure
completed: 2026-01-27
duration: 4min

tags:
  - bash
  - jq
  - shell-scripting
  - logging
  - concurrency

requires:
  - phases:
      - 03-01  # Worker infrastructure (.worker/ directory)
  - external:
      - jq (JSON processing)
      - gh CLI (GitHub API access)
      - mkdir (atomic directory creation)

provides:
  - logger.sh: Structured JSON event logging with single-line JSONL output
  - lock.sh: Atomic lock management with staleness detection
  - parser.sh: GitHub issue body section extraction

affects:
  - 03-03  # Worker execution skill will source these libraries
  - 03-04  # Documentation and verification will reference these patterns

tech-stack:
  added:
    - jq for JSON generation (handles escaping)
    - awk for section extraction (robust multi-line parsing)
    - mkdir for atomic locking (Windows-compatible)
  patterns:
    - Structured JSON logging with consistent event schema
    - Directory-based atomic locking (flock alternative for Windows)
    - Trap-based cleanup for graceful shutdown
    - Configuration-driven thresholds from .worker/config.json

key-files:
  created:
    - .claude/skills/worker/lib/logger.sh (98 lines, 2380 bytes)
    - .claude/skills/worker/lib/lock.sh (136 lines, 3898 bytes)
    - .claude/skills/worker/lib/parser.sh (119 lines, 3143 bytes)
  modified: []

decisions:
  - id: LOCK-MKDIR
    summary: Use mkdir instead of flock for atomic locking
    rationale: flock not available on Windows/MINGW64; mkdir is atomic on NTFS and cross-platform
    alternatives: [flock (Linux-only), lockfile command (not available), PID files (race conditions)]
    impact: Lock directories instead of lock files; staleness detected via metadata.json mtime

  - id: LOG-JQ
    summary: Use jq for all JSON generation
    rationale: Handles escaping correctly; produces valid single-line JSON; prevents malformed logs
    alternatives: [manual string concatenation (error-prone), printf with escaping (complex)]
    impact: Every log event uses jq -n with --arg flags; data object constructed dynamically

  - id: PARSE-AWK
    summary: Use awk for section extraction
    rationale: Robust multi-line pattern matching; handles various formatting; standard tool
    alternatives: [sed (less readable), grep with -A/-B (fragile), custom parsing]
    impact: extract_section uses awk to capture content between ## headers
```

---

## What Was Built

Created three reusable shell libraries that the worker skill will source:

**1. logger.sh - Structured JSON Event Logging**
- Single-line JSONL output (one event per line)
- Consistent schema: timestamp, event_type, event_id, session_id, data
- Uses jq for JSON generation (handles escaping automatically)
- init_logging creates unique log file and session ID
- log_event accepts arbitrary --arg key value pairs
- log_session_end for graceful shutdown logging

**2. lock.sh - Atomic Lock File Management**
- Atomic lock acquisition using mkdir (Windows-compatible)
- Staleness detection using config threshold (default 30 minutes)
- Force flag for overriding stale locks
- Lock metadata in JSON format (issue, PID, timestamp, hostname)
- Trap-based cleanup ensures release on EXIT/SIGTERM/SIGINT
- check_lock_status for inspecting lock state

**3. parser.sh - GitHub Issue Body Section Extraction**
- Fetches issue data via gh CLI (title, body, labels)
- Extracts ## sections using awk (Summary, Context, Acceptance Criteria, etc.)
- Handles multi-line content within sections
- Validates required sections (Summary, Acceptance Criteria)
- Exports parsed content to ISSUE_* global variables
- get_parsed_issue_json for logging parsed data

**Key Integration Points:**
- All libraries use jq for JSON generation (consistent escaping)
- Lock library reads threshold from .worker/config.json
- Parser validates issue structure before worker execution
- Logger provides session tracking across worker lifecycle

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Windows compatibility: mkdir-based locking instead of flock**

- **Found during:** Task 2 - Lock library implementation
- **Issue:** flock command not available on Windows/MINGW64 bash environment
- **Fix:** Replaced flock-based locking with atomic mkdir approach
  - Lock directories instead of lock files (mkdir is atomic on NTFS)
  - Lock metadata stored in metadata.json within lock directory
  - Staleness detection using stat on metadata file mtime
  - release_lock removes entire lock directory
- **Files modified:** .claude/skills/worker/lib/lock.sh
- **Commit:** aff8d94
- **Rationale:** mkdir is atomic on most filesystems including NTFS, providing equivalent guarantees to flock. This is a standard fallback pattern for cross-platform shell scripts.

**2. [Rule 2 - Missing Critical] Dynamic jq object construction for log events**

- **Found during:** Task 1 - Logger verification
- **Issue:** Initial implementation passed --arg flags to jq but didn't construct object from them
- **Fix:** Added argument parsing loop to collect --arg pairs and build jq expression dynamically
  - Parse --arg key value triplets into arrays
  - Construct jq expression `{key1: $key1, key2: $key2, ...}` from argument names
  - Pass both --arg flags and expression to jq -n
- **Files modified:** .claude/skills/worker/lib/logger.sh
- **Commit:** db19cda (amended during verification)
- **Rationale:** log_event("type", --arg k v, --arg k2 v2) must produce {data: {k: v, k2: v2}} structure

---

## Testing & Verification

### Logger Verification
```bash
source .claude/skills/worker/lib/logger.sh
init_logging 999
log_event "test_event" --arg key1 "value1" --arg key2 "value2"
log_event "another_event" --arg message "Test with \"quotes\" and newline"
cat "$LOG_FILE" | jq .  # Validates each line is valid JSON
```

**Result:** All events produced valid single-line JSON with proper escaping

### Lock Verification
```bash
source .claude/skills/worker/lib/lock.sh
acquire_lock 998
check_lock_status 998    # Shows metadata: PID, timestamp, hostname
release_lock
check_lock_status 998    # Returns "Not locked"

# Test double acquire (should fail)
bash -c 'source lock.sh; acquire_lock 996; acquire_lock 996'
# [error] Worker already running for issue #996
```

**Result:** Lock prevents concurrent acquisition; staleness detection works; force flag overrides

### Parser Verification
```bash
source .claude/skills/worker/lib/parser.sh
ISSUE_BODY="## Summary
Content here

## Acceptance Criteria
- [ ] Item 1"

extract_section "Summary"            # Returns "Content here"
extract_section "Acceptance Criteria" # Returns "- [ ] Item 1"
```

**Result:** Section extraction handles multi-line content; validates required sections

### Integration Test
```bash
source logger.sh
source lock.sh
source parser.sh

init_logging 999
log_event "test" --arg source "integration"
acquire_lock 999
release_lock
```

**Result:** All libraries source without conflicts; functions operational

---

## Key Metrics

- **Files created:** 3 shell libraries (353 total lines)
- **Functions exported:** 10 (init_logging, log_event, log_session_end, acquire_lock, release_lock, check_lock_status, get_staleness_threshold, parse_issue_body, extract_section, validate_issue_for_worker)
- **Dependencies:** jq (JSON), gh CLI (GitHub), mkdir (locking), awk (parsing), stat (staleness)
- **Test coverage:** Manual verification of all core functions
- **Commits:** 3 atomic commits (one per task)

---

## Success Criteria Met

- [x] `.claude/skills/worker/lib/logger.sh` produces valid JSONL events
- [x] `.claude/skills/worker/lib/lock.sh` provides atomic locking with staleness detection
- [x] `.claude/skills/worker/lib/parser.sh` extracts issue sections correctly
- [x] All libraries can be sourced together without conflicts
- [x] Functions use jq for JSON, mkdir for locks, gh CLI for GitHub

---

## Next Phase Readiness

**Ready for 03-03 (Worker Execution Skill):**
- Logger provides structured event logging for all worker lifecycle events
- Lock ensures single worker per issue with crash detection
- Parser validates and extracts issue structure for planning phase
- All functions tested and verified operational

**Blockers:** None

**Concerns:**
- Lock cleanup on crash relies on trap; extreme cases (kill -9) won't clean up
  - Staleness detection handles this case (--force flag after threshold)
- Parser assumes ## header format; unstructured issues will fail validation
  - validate_issue_for_worker catches this and provides clear error

**Recommendations:**
- Worker skill should call validate_issue_for_worker before attempting execution
- Worker skill should set up trap handlers early to ensure log_session_end called
- Consider adding --debug flag to worker that enables verbose logging

---

## Commits

| Hash | Message | Files |
|------|---------|-------|
| db19cda | feat(03-02): create JSON event logger library | logger.sh |
| aff8d94 | feat(03-02): create lock file management library | lock.sh |
| 106ed31 | feat(03-02): create issue body parser library | parser.sh |

---

**Completed:** 2026-01-27
**Duration:** 4 minutes
**Executor:** Claude (GSD execution agent)

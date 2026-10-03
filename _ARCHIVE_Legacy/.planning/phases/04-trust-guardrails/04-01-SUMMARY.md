---
phase: 04-trust-guardrails
plan: 01
subsystem: infra
tags: [yaml, yq, trust-system, guardrails, safety-floor]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Agent manifest schema and YAML structure
  - phase: 03-single-worker
    provides: Worker execution infrastructure requiring safety controls
provides:
  - Trust guardrails YAML configuration with safety floor (12 critical patterns)
  - yq installation tooling for YAML processing
  - Hierarchical trust level system (0-4) with response mappings
  - Violation scoring and decay system
affects:
  - 04-02 (guardrail library implementation will read this config)
  - 04-03 (command validation uses these patterns)
  - 05-orchestrator (trust-aware routing uses these levels)

# Tech tracking
tech-stack:
  added: [yq v4.44.1]
  patterns: [Safety floor pattern, Trust level progression, Violation point system]

key-files:
  created:
    - .claude/trust-guardrails.yaml
    - scripts/worker/install-yq.sh
  modified: []

key-decisions:
  - "yq installed to $HOME/bin instead of /usr/bin (Windows/MINGW64 permission constraints)"
  - "Safety floor patterns use regex for flexibility while remaining strict on critical operations"
  - "Trust level 0 blocks ALL operations (even low severity) for complete lockdown capability"
  - "Violation points decay with clean actions (5 points per action) to reward good behavior"

patterns-established:
  - "Safety floor: Non-overridable critical patterns that always block regardless of trust"
  - "Hierarchical trust: 0 (no trust) → 4 (full autonomy) with graduated response mappings"
  - "Scope enforcement: Glob patterns require literal separators and leading dots"

# Metrics
duration: 3min
completed: 2026-01-28
---

# Phase 4 Plan 01: Trust Guardrails Configuration Summary

**YAML config with 12 safety floor patterns (always block), 6 destructive operations (confirm/block), trust levels 0-4, and yq v4.44.1 tooling**

## Performance

- **Duration:** 3 minutes
- **Started:** 2026-01-28T04:39:36Z
- **Completed:** 2026-01-28T04:43:28Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Trust guardrails YAML configuration with hierarchical inheritance structure
- Safety floor: 12 critical patterns (catastrophic operations always blocked)
- Destructive operations: 6 high-severity patterns with confirm/block actions
- Trust levels 0-4 with graduated response mappings (block/confirm/allow)
- Violation scoring system: 20/40/60 thresholds with 5-point decay per clean action
- yq YAML processor installed for configuration validation and manipulation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create yq installation script** - `38a47f1` (chore)
2. **Task 2: Create trust guardrails YAML configuration** - `cff8264` (feat)

## Files Created/Modified
- `.claude/trust-guardrails.yaml` - Project-level guardrail rules with safety floor, destructive operations, trust levels, violation scoring, scope enforcement, and audit config (180 lines)
- `scripts/worker/install-yq.sh` - Bash script to install yq v4.44.1 to $HOME/bin with idempotency and PATH setup (59 lines)

## Decisions Made

**1. User bin directory for yq installation**
- **Decision:** Install yq to `$HOME/bin` instead of `/usr/bin`
- **Rationale:** Windows/MINGW64 environment restricts write access to `/usr/bin`, but `$HOME/bin` is user-writable and automatically in PATH for most shell configurations
- **Impact:** Installation script works without elevated permissions

**2. Safety floor pattern design**
- **Decision:** Use regex patterns instead of exact string matching for critical operations
- **Rationale:** Provides flexibility to catch variations (spacing, flags) while maintaining strictness on catastrophic operations
- **Examples:** `rm\s+-rf\s+/` catches "rm -rf /" with various spacing

**3. Trust level 0 behavior**
- **Decision:** Level 0 blocks ALL operations including low severity
- **Rationale:** Provides complete lockdown capability for untrusted or problematic agents without partial execution risk
- **Progression:** Agents must earn Level 1 to perform even safe operations

**4. Violation point decay**
- **Decision:** 5 points removed per clean action with 100 action max for full reset
- **Rationale:** Rewards sustained good behavior while preventing indefinite point accumulation from minor violations
- **Balance:** Takes 12 clean actions to recover from critical violation (30 points → 0)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Changed yq installation directory**
- **Found during:** Task 1 (yq installation script)
- **Issue:** `/usr/bin` write-protected on Windows/MINGW64, preventing yq installation
- **Fix:** Changed INSTALL_DIR to `$HOME/bin` and added PATH export with persistence instructions
- **Files modified:** scripts/worker/install-yq.sh
- **Verification:** yq installs successfully and `yq --version` returns v4.44.1
- **Committed in:** 38a47f1 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking issue)
**Impact on plan:** Essential fix for Windows compatibility. No scope creep. Installation still achieves same outcome (yq functional).

## Issues Encountered

**PATH inconsistency in Bash sessions**
- **Issue:** Some bash invocations don't inherit `$HOME/bin` in PATH automatically
- **Workaround:** Scripts that use yq must explicitly `export PATH="$HOME/bin:$PATH"` before calling yq
- **Resolution:** Installation script includes instructions for adding to ~/.bashrc for persistence
- **Impact:** Minor - doesn't affect functionality, just requires explicit PATH setup in scripts

## User Setup Required

None - no external service configuration required.

Users should add `export PATH="$HOME/bin:$PATH"` to `~/.bashrc` for persistent yq access across all shell sessions.

## Next Phase Readiness

**Ready for 04-02 (Guardrail Library Implementation):**
- Trust guardrails YAML config is valid and complete
- Safety floor patterns defined and ready to be loaded
- Trust level mappings established for response logic
- yq available for YAML parsing in bash scripts

**Ready for 04-03 (Command Validation Integration):**
- Pattern definitions ready for pre-execution checks
- Violation scoring thresholds defined for enforcement
- Audit configuration ready for logging integration

**No blockers.**

---
*Phase: 04-trust-guardrails*
*Completed: 2026-01-28*

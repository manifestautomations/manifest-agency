# Codebase Concerns

**Analysis Date:** 2026-01-31

## Tech Debt

**Library sourcing applies global shell options:**
- Issue: Library scripts in `scripts/worker/lib/` use `set -euo pipefail` at global scope. When sourced into interactive shells, the `-u` flag applies globally, breaking user shell configurations that reference undefined variables (e.g., `BP_PIPESTATUS` from bash-preexec plugins).
- Files:
  - `scripts/worker/lib/graph-parser.sh` (line 37-40 contains include guard but prior to guard is no explicit set statement - set is applied globally)
  - `scripts/worker/lib/scope-validator.sh`
  - `scripts/worker/lib/subagent-scope.sh`
  - `scripts/worker/lib/timeout-manager.sh`
- Impact: Interactive shells break when sourcing libraries; users cannot interactively test or debug functions. Diagnosed in Phase 6 UAT (test 9).
- Fix approach: Wrap function definitions in subshells with their own options, save/restore shell options before/after setting them, or remove global `set` statements and rely on calling scripts to set options.

**Library path mismatch in execute.sh:**
- Issue: `scripts/worker/execute.sh` line 22 references `LIB_DIR="$REPO_ROOT/.claude/skills/worker/lib"` but Phase 6 parallelization libraries are located at `scripts/worker/lib/` not `.claude/skills/worker/lib/`.
- Files: `scripts/worker/execute.sh` (line 22)
- Impact: Script fails to find and source graph-parser.sh and related Phase 6 libraries. Phase 6 UAT test 8 reports: "scripts/worker/execute.sh: line 32: /c/Users/tyler/Manifest Automations/.claude/skills/worker/lib/graph-parser.sh: No such file or directory".
- Fix approach: Update LIB_DIR path to correctly point to `scripts/worker/lib/` where new parallelization libraries are installed.

## Known Bugs

**Stale lock detection timing edge case:**
- Symptoms: Lock staleness detection uses stat to get file modification time, but this varies between filesystems (Linux `-c %Y`, macOS `-f %m`). On some systems, cached timestamps may not reflect actual lock age.
- Files: `.claude/skills/worker/lib/lock.sh` (lines 48-50)
- Trigger: Running `acquire_lock` on issue with existing stale lock in different environments. stat command may return inconsistent timestamps.
- Workaround: Use `--force` flag to override stale locks when standard acquisition fails. Manual cleanup: `rm -rf .worker/locks/issue-{N}.lock`.

**Dispatcher concurrency with slow workers:**
- Symptoms: `scripts/orchestrator/dispatch.sh` maintains worker PID tracking with associative arrays. If a worker crashes without clean exit, the array entry persists and `wait_for_worker()` line 200 may fail to detect completion.
- Files: `scripts/orchestrator/dispatch.sh` (lines 43-48, 188-227)
- Trigger: Worker process killed abruptly (SIGKILL), or process exits without updating metadata.
- Workaround: Use `scripts/orchestrator/dispatch.sh --status` to check running workers; manually kill stale processes with `kill -9 PID` if needed.

## Security Considerations

**Cross-workspace context contamination risk:**
- Risk: Workers in one workspace could inadvertently leak context (file paths, conventions, secrets) into another workspace if workspace isolation is not enforced at execution time.
- Files: `scripts/worker/execute.sh`, `scripts/orchestrator/dispatch.sh` (dispatch logic)
- Current mitigation: Each workspace has isolated `.worker/` directory and uses separate GitHub issue/PR spaces. Worktrees are per-workspace. Workers do not share environment variables across workspaces.
- Recommendations:
  1. Enforce `.worker/` isolation at dispatch time - ensure execute.sh runs in correct workspace root
  2. Audit environment variable propagation to spawned subagents
  3. Add validation that PR/issue repos match declared workspace before execution

**GitHub PAT exposure in logs:**
- Risk: GitHub CLI operations log authentication details. If logs are captured, PAT may be exposed.
- Files: All `scripts/github/*.sh` scripts use `gh` CLI which may log auth context in stderr
- Current mitigation: GitHub CLI suppresses PAT in most output; `.gitignore` excludes logs from version control.
- Recommendations:
  1. Redirect gh CLI stderr to secure log file (not stdout)
  2. Audit `.worker/logs/` for any credential leakage before sharing
  3. Document PAT rotation procedures

## Performance Bottlenecks

**Dependency graph traversal without caching:**
- Problem: `scripts/orchestrator/dispatch.sh` calls `get_ready_issues` (line 276) and `detect_cascade` (line 340) repeatedly in dispatch loops without caching results. Each call re-queries GitHub via `gh issue list`.
- Files: `scripts/orchestrator/dispatch.sh` (lines 269-358)
- Cause: No local cache of issue states. Each dispatch wave performs fresh GitHub queries.
- Improvement path:
  1. Cache issue state locally during dispatch session (update cache only between waves)
  2. Use `gh issue list --cache` if available, or implement local JSON cache of issue labels/status
  3. Batch queries: fetch all ready issues once per wave instead of per-issue

**YAML parsing without streaming:**
- Problem: `scripts/worker/lib/graph-parser.sh` loads entire PLAN.md into memory and uses sed/grep to extract execution graph. For large task graphs (100+ tasks), this becomes slow.
- Files: `scripts/worker/lib/graph-parser.sh` (lines 59-60, YAML extraction logic)
- Cause: Full file load + string manipulation instead of streaming YAML parser.
- Improvement path:
  1. For graphs under 50 tasks, current approach is acceptable
  2. For larger graphs, consider yq-based YAML extraction (faster, standard tool)
  3. Profile execution time with real task graphs to determine if optimization is needed

## Fragile Areas

**Worker state machine depends on label accuracy:**
- Files: `scripts/worker/execute.sh`, `scripts/orchestrator/dispatch.sh`
- Why fragile: Worker state is tracked via GitHub issue labels (worker:planning, worker:executing, worker:complete, worker:failed). If labels are manually edited or deleted, state becomes corrupt. No validation that labels match actual execution state.
- Safe modification:
  1. Never manually edit worker labels - use scripts only
  2. Add validation function to audit.sh that checks label consistency with `.worker/` metadata
  3. Before dispatch, verify issue is in expected state (e.g., no stale worker:executing label on open issue)
- Test coverage: Phase 12 VERIFICATION passes, but lacks edge case tests for label corruption scenarios

**Subagent scope validation missing runtime enforcement:**
- Files: `scripts/worker/lib/scope-validator.sh`
- Why fragile: `validate_scope_subset` function validates scope at plan time, but subagent execution is not re-validated. A subagent could write to files outside declared scope if the validation logic is bypassed.
- Safe modification:
  1. Add runtime check before subagent commit: verify all modified files are within declared scope
  2. Store scope in subagent metadata, validate before returning results
  3. Add test case: subagent that attempts write outside scope should fail with clear error
- Test coverage: Phase 6 UAT skipped test 13 (scope validation tests)

**Lock file cleanup on force release:**
- Files: `.claude/skills/worker/lib/lock.sh` (lines 56-62)
- Why fragile: When forcing stale lock release, directory is deleted with `rm -rf`. If directory path is wrong or permissions are odd, deletion could fail silently.
- Safe modification:
  1. Check `mkdir` success after force deletion (line 59)
  2. Log detailed error if force acquisition fails
  3. Add `--inspect` flag to show lock directory contents before forcing
- Test coverage: Lock is tested in Phase 3 VERIFICATION but force release path not explicitly tested

## Scaling Limits

**Concurrent worker count hardcoded to 3:**
- Current capacity: 3 workers running in parallel (line 35 in dispatch.sh)
- Limit: With 3 concurrent workers spawning subagents (Phase 6), potential for 3 * N subprocesses. No ulimit enforcement.
- Scaling path:
  1. Make MAX_CONCURRENT configurable via environment variable or config file
  2. Add resource monitoring: check available memory/CPU before spawning additional workers
  3. Document recommended values for different machine specs (development 3, staging 5, production 10)

**Issue query result pagination:**
- Current capacity: `gh issue list` returns up to 30 items by default (undocumented in scripts)
- Limit: If more than 30 issues exist in "ready" or "failed" state, pagination will skip issues
- Scaling path:
  1. Add `--limit` flag to gh issue queries or use `--paginate` if available
  2. For aggregate queries across multiple projects (v1.1), ensure pagination is handled explicitly
  3. Add comment documenting assumed limits for each query

**Worker timeout hardcoded to 24 hours:**
- Files: Approval workflow timeout in Phase 7 documentation
- Current capacity: Single approval timeout of 24 hours for normal tasks
- Limit: Cannot customize timeout per task type. Critical tasks have infinite timeout (9999-12-31) which blocks cleanup
- Scaling path:
  1. Add configurable timeout per approval type in `.worker/config.json`
  2. Implement auto-cleanup for critical violations after configurable period (default: 7 days)
  3. Add timeout_policy to task YAML: quick=1h, normal=24h, critical=7d

## Dependencies at Risk

**Bash version assumptions:**
- Risk: Code uses `wait -n` (bash 4.3+), associative arrays (bash 4.0+), and array subscript syntax not available in bash 3.x
- Impact: Scripts fail on older systems (macOS 10.14 ships bash 3.2). No version check at runtime.
- Migration plan:
  1. Add `declare -r BASH_VERSION_REQUIRED=4.3` check at top of dispatch.sh
  2. Provide error message directing users to upgrade bash
  3. Document minimum supported bash version in README

**GitHub CLI availability:**
- Risk: All orchestration depends on `gh` CLI. If gh is not installed or authentication fails, entire system breaks silently (commands return 1 without clear error).
- Impact: Users without GitHub CLI or with expired PAT see cryptic errors in worker logs
- Migration plan:
  1. Add `command -v gh` check in orchestrator startup
  2. Test GitHub authentication early: `gh auth status` in initialization
  3. Provide clear error message if gh is missing or auth fails

**jq dependency (implicit):**
- Risk: JSON manipulation throughout codebase assumes `jq` is available. No fallback if jq is missing.
- Impact: Dispatch fails silently on systems without jq
- Migration plan:
  1. Document jq as required system dependency
  2. Add `command -v jq` validation in scripts/orchestrator/dispatch.sh before first use
  3. Provide installation instructions in error message

**yq for YAML processing (not yet required, but planned):**
- Risk: Phase 6 graph-parser.sh uses sed/grep for YAML extraction. Future optimization to use `yq` would introduce new dependency.
- Impact: If yq is not installed, graph parsing fails
- Migration plan:
  1. If yq is added, make it optional with fallback to sed/grep
  2. Document yq as optional performance optimization
  3. Test both paths in CI

## Missing Critical Features

**Approval timeout enforcement:**
- Problem: Approvals created with 24-hour timeout have no automatic cleanup. Expired approvals remain in `.worker/approvals/` indefinitely.
- Blocks: Cannot reliably track approval status over long periods; stale approvals pollute approval queue
- Current state: check_stale_approvals detects expired approvals but does not delete them. auto-deny-expired function skips critical violations.

**Subagent failure isolation:**
- Problem: If a subagent fails during parallel execution, parent task may not fail cleanly. aggregate-wave.sh collects results but error propagation is unclear.
- Blocks: Cannot reliably detect partial failures in parallelized work
- Current state: Subagent execution uses try/catch patterns but aggregation error handling is not documented

**Cross-workspace dependency validation:**
- Problem: No validation that "Blocked by org/repo#N" references point to valid issues in other workspaces.
- Blocks: Cannot prevent dispatch of work blocked by non-existent cross-repo dependencies
- Current state: Mentioned as "future feature" in FEATURES.md but not implemented

**Workspace health trend analysis:**
- Problem: No historical metrics tracking. Each aggregation snapshot is standalone; cannot detect velocity decline or anomalies.
- Blocks: Cannot surface "Project X has slowing velocity" in CEO briefing
- Current state: Portfolio-briefing.sh generates current metrics but no historical comparison

## Test Coverage Gaps

**Graph parsing with realistic task graphs:**
- What's not tested: Actual PLAN.md files with 20+ task dependencies, complex DAG patterns (fan-in, fan-out, diamond dependencies)
- Files: `scripts/worker/lib/graph-parser.sh`
- Risk: Cycle detection, topological sort may fail on real graphs; current tests use simple linear graphs
- Priority: High - Phase 6 parallelization depends on correct DAG validation

**Stale lock forced acquisition in parallel environment:**
- What's not tested: Two workers attempt force-acquire same stale lock simultaneously. TOCTOU race condition possible.
- Files: `.claude/skills/worker/lib/lock.sh` (lines 56-62)
- Risk: Both workers might acquire lock, violating exclusivity
- Priority: High - Concurrency is core to Phase 6

**Cascade failure detection accuracy:**
- What's not tested: detect_cascade function with multi-level dependency chains (A blocks B blocks C). Does it detect all transitive blockers?
- Files: `scripts/orchestrator/dispatch.sh` (lines 337-345)
- Risk: Some blocked issues may not be labeled, creating invisible blocks
- Priority: Medium - affects end-to-end workflows but rare in practice

**Cross-workspace dispatch routing with similar project names:**
- What's not tested: workspace-resolve.sh with projects named "project", "project-v2", "project-alpha". Fuzzy matching may route to wrong workspace.
- Files: `scripts/workspace/workspace-resolve.sh`, `scripts/dispatch/fuzzy-match.sh`
- Risk: Work dispatched to wrong project; requires manual intervention
- Priority: Medium - blocks multi-workspace adoption

**Approval workflow with concurrent approval/denial:**
- What's not tested: User approves issue while auto-deny is processing timeout expiry. Race condition on approval file.
- Files: `.claude/skills/ceo-dashboard/scripts/approval-workflow.sh`
- Risk: Approval state becomes inconsistent
- Priority: Medium - rare edge case but high impact if it occurs

---

*Concerns audit: 2026-01-31*

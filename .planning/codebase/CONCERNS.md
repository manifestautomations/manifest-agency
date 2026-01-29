# Codebase Concerns

**Analysis Date:** 2026-01-29

## Tech Debt

### Shell Library Sourcing with `set -euo pipefail`

**Issue:** Library files intended to be sourced into other shells have `set -euo pipefail` at the global scope, causing the `-u` (nounset) flag to apply to the entire parent shell when sourced. This breaks interactive shells that use undefined variables in their configuration (e.g., prompt plugins using `BP_PIPESTATUS`).

**Files:**
- `.claude/skills/worker/lib/validator.sh` (line 6)
- `.claude/skills/worker/lib/hooks.sh` (line 18)

**Impact:**
- Cannot interactively source library files in developer shells
- Breaks bash prompt configuration for users with fancy prompt plugins
- Prevents manual debugging and testing of library functions
- Affects any workflow that sources these files into interactive sessions

**Fix approach:**
Either (1) wrap function bodies in subshells that have their own shell options, or (2) save and restore shell options around sourcing, or (3) use function-scoped alternatives instead of global `set` directives. Alternatively, design these files as executable scripts with shebang rather than sourced libraries.

**Status:** Known issue documented in `.planning/debug/bp-pipestatus-unbound.md`

---

### Complex Command Execution with `eval`

**Issue:** `.claude/skills/worker/lib/hooks.sh` line 64 uses `eval "$command" 2>&1` to execute arbitrary commands captured from function arguments. This pattern is inherently unsafe and difficult to debug.

**Files:**
- `.claude/skills/worker/lib/hooks.sh` (line 64)

**Impact:**
- Word splitting and glob expansion applied to user input
- Difficult to predict behavior with special characters or spaces
- Hard to trace what command actually executed for debugging
- Potential injection vector if command strings contain untrusted data

**Fix approach:**
Use array-based command execution with `"${array[@]}"` instead of string concatenation and eval. Refactor `execute_with_hooks` to accept commands as separate arguments or array variables.

---

### Worker Library Path Resolution

**Issue:** `.planning/phases/06-worker-parallelization/06-UAT.md` documents that `scripts/worker/execute.sh` line 22 originally pointed to `.claude/skills/worker/lib` but Phase 6 libraries are actually in `scripts/worker/lib`. This created a mismatch between library locations.

**Files:**
- `scripts/worker/execute.sh` (lines 22, 36-38)
- Workaround: `WORKER_SCRIPT_DIR` saved on line 25

**Impact:**
- Confusion about canonical library locations
- Risk of sourcing wrong version if paths inconsistent
- Documentation and code paths diverge

**Fix approach:**
Standardize all Phase 6 libraries to single location. Consider moving all worker libraries to `.claude/skills/worker/lib` or all to `scripts/worker/lib` consistently. Update documentation and path variables throughout.

**Status:** Partially mitigated with `WORKER_SCRIPT_DIR` variable, but underlying inconsistency remains.

---

## Known Bugs

### Worker Parallelization UAT Failures

**Symptoms:**
- Cannot source `scripts/worker/lib/graph-parser.sh` due to unbound variable error
- Scripts fail to execute or parsing fails in interactive testing

**Files:**
- `scripts/worker/lib/graph-parser.sh` (library sourcing)
- `scripts/worker/execute.sh` (sourcing Phase 6 libs)

**Root cause:** Combination of library files having `set -euo pipefail` and being sourced into environments where undefined variables exist.

**Workaround:** Run scripts in execution context (not interactive sourcing); use `--serial` flag to bypass parallelization features.

---

## Security Considerations

### Approval Flow Timeout Risk

**Risk:** `.claude/skills/worker/lib/hooks.sh` line 260 uses `read -t` with a default confirmation timeout. If approval timeout expires without user action, command is denied, but system doesn't distinguish between denial and timeout. This could mask race conditions in approval workflows.

**Files:**
- `.claude/skills/worker/lib/hooks.sh` (lines 249-260)

**Current mitigation:** Timeout logged separately from denial, but same return code (1) for both paths.

**Recommendations:**
- Return different exit codes for timeout vs. denial (e.g., 124 for timeout per convention)
- Log timeout events with higher visibility to distinguish from intentional denial
- Consider re-prompting instead of failing on timeout for certain approval types

---

### Dynamic Command Execution in Hooks

**Risk:** `.claude/skills/worker/lib/hooks.sh` executes arbitrary commands from function arguments after guard checks. If validation (pre_hook) can be bypassed or has gaps, any command gets executed with the trust level of the executing agent.

**Files:**
- `.claude/skills/worker/lib/hooks.sh` (lines 54-78)

**Current mitigation:**
- pre_hook() validates against guardrails before execution
- Trust level gating in validator.sh

**Recommendations:**
- Use allowlist-based command validation instead of pattern matching
- Restrict eval-based execution to known safe command formats
- Log all command execution with full context for audit trail
- Consider sandboxed execution for untrusted command sources

---

### Scope Escalation in Sub-Agent Spawning

**Risk:** `scripts/worker/lib/subagent-scope.sh` derives constraints for sub-agents from parent scope. If a sub-agent is assigned a scope larger than its parent, it could escalate permissions.

**Files:**
- `scripts/worker/lib/subagent-scope.sh`
- `.claude/skills/worker/lib/validator.sh`

**Current mitigation:**
- `check_nesting_limit()` prevents excessive nesting
- `validate_scope_subset()` should prevent escalation

**Recommendations:**
- Verify scope validation runs BEFORE sub-agent spawn
- Add explicit parent-child scope relationship checks
- Log any scope derivation decisions for audit
- Test with adversarial scope definitions

---

## Performance Bottlenecks

### Wave-Based Parallelization With No Concurrency Limit

**Problem:** `scripts/worker/aggregate-wave.sh` spawns entire waves in parallel without limiting concurrent sub-agents. With 50+ independent tasks, this could spawn 50+ concurrent processes, exhausting system resources.

**Files:**
- `scripts/worker/aggregate-wave.sh` (line 43)
- `scripts/worker/spawn-subagent.sh` (line 177)

**Cause:** No rate limiting on `spawn_wave()` calls

**Improvement path:**
- Add configurable max concurrent sub-agents (default 4-8)
- Implement sub-wave batching (split large waves into smaller batches)
- Add resource monitoring to pause spawning if CPU/memory threshold exceeded
- Document performance characteristics as function of wave size

---

### Large File Globbing in Scope Validation

**Problem:** `scripts/worker/lib/scope-validator.sh` line 42-43 enables `nullglob` and `globstar` and expands glob patterns for every scope check. If patterns match thousands of files, globbing becomes slow.

**Files:**
- `scripts/worker/lib/scope-validator.sh` (lines 24-64)

**Cause:** No caching of glob results; re-computed on each validation

**Improvement path:**
- Cache glob expansion results per scope pattern
- Add glob expansion timeout with fallback to pattern-based matching
- Use file tree indexes instead of filesystem globbing for large projects

---

### GitHub API Rate Limiting

**Problem:** Orchestrator scripts (`scripts/orchestrator/*.sh`) make multiple `gh` CLI calls per workflow without rate limit awareness. With parallel worker execution, GitHub API rate limits could be exceeded, blocking work.

**Files:**
- `scripts/orchestrator/aggregate.sh`
- `scripts/orchestrator/dispatch.sh`
- `scripts/orchestrator/graph.sh`

**Current mitigation:** None visible; no exponential backoff or rate limit checking

**Improvement path:**
- Implement rate limit headers parsing and backoff strategy
- Cache GitHub issue/PR metadata locally
- Batch API calls where possible
- Monitor rate limit consumption

---

## Fragile Areas

### Execution Graph Parsing With String-Based YAML

**Files:** `scripts/worker/lib/graph-parser.sh`

**Why fragile:**
- Extracts YAML from markdown by regex (line 49-62) - brittle to spacing changes
- No YAML schema validation - accepts any structure
- Dependency list parsing (line 69) uses simple string splitting

**Safe modification:**
- Add YAML schema validation with `yq` before processing
- Test with various markdown formatting (extra whitespace, code blocks, etc.)
- Add explicit error messages for malformed graphs

**Test coverage:** Limited; UAT tests are mostly skipped due to sourcing issues

---

### Issue-Based State Management in GitHub

**Files:**
- `scripts/orchestrator/dispatch.sh`
- `.claude/skills/worker/lib/parser.sh`

**Why fragile:**
- GitHub issues used as database without transactions (Pitfall #3 in PITFALLS.md)
- Concurrent workers may overwrite each other's updates
- No optimistic locking or version checking (ETags)
- Sub-issue limit of 100 hardcoded in GitHub (not validated)

**Safe modification:**
- Always read issue before updating to detect concurrent changes
- Use GitHub API ETags for optimistic locking
- Document file ownership boundaries
- Test multi-agent concurrent modifications

**Test coverage:** Phase 3-5 verified basic workflow; Phase 6 parallelization added concurrency but not concurrent state testing

---

### Timeout-Based Termination in Sub-Agents

**Files:** `scripts/worker/lib/timeout-manager.sh`

**Why fragile:**
- Two-stage termination (SIGTERM then SIGKILL) at line 94-105 assumes clean shutdown
- Sub-processes may ignore SIGTERM or take long to clean up
- Parent may not detect failed termination and leak processes

**Safe modification:**
- Verify process actually terminates with `ps` check after SIGKILL
- Add configurable grace period for cleanup
- Log timeout events to audit trail
- Test with long-running processes

**Test coverage:** Skipped in UAT; needs manual testing

---

## Scaling Limits

### Sub-Agent Nesting Depth

**Current capacity:** Hardcoded 2-level nesting max (`.planning/phases/06-worker-parallelization/06-RESEARCH.md`)

**Limit:** If a Phase 6 sub-agent spawns its own sub-agents, nesting exceeds 2 levels and is rejected.

**Scaling path:**
- Increase `NESTING_LIMIT` in `scripts/worker/lib/subagent-scope.sh`
- Test resource consumption at each nesting level
- Add documentation of recommended limits by problem size

---

### GitHub Sub-Issue Capacity

**Current capacity:** GitHub enforces 100 sub-issue max per parent issue

**Limit:** Any execution graph with > 100 tasks cannot be fully represented as sub-issues

**Scaling path:**
- Implement parent issue splitting (100-task chunks)
- Use project issues instead of sub-issues for large decompositions
- Document task count limits in phase planning

---

### Worker Command Execution Concurrency

**Current capacity:** No limit on concurrent sub-agent execution

**Scaling path:**
- Add configurable worker concurrency limit
- Implement queue-based execution for fairness
- Profile resource usage at various concurrency levels

---

## Dependencies at Risk

### yq Dependency for YAML Processing

**Risk:** `scripts/worker/lib/graph-parser.sh` depends on `yq` being installed and in PATH. No fallback if missing.

**Files:**
- `scripts/worker/lib/validator.sh` (line 18-20) checks for yq, fails if missing
- `scripts/worker/lib/graph-parser.sh` (implicit)

**Impact:** If `yq` not installed, all graph parsing fails

**Migration plan:** Implement YAML parsing in bash using string manipulation or `jq` (if already required), removing yq dependency

---

### GitHub CLI Rate Limits

**Risk:** Heavy reliance on `gh` CLI for all coordination. GitHub has strict rate limits (60 calls/hour unauthenticated, 5000/hour authenticated).

**Impact:** Multi-agent workflows could exceed limits during peak parallelization

**Migration plan:** Add GitHub API token caching, implement local state mirrors, batch operations

---

## Missing Critical Features

### Observability and Distributed Tracing

**What's missing:**
- No structured logging format across scripts (mix of echo, logging functions, jq)
- No correlation IDs to link work across agents
- No OpenTelemetry or distributed tracing integration
- No metrics collection (execution time, resource usage, success rates)

**Blocks:**
- Debugging multi-agent failures (which agent caused the issue?)
- Performance optimization (where is time spent?)
- SLA monitoring (are agents meeting latency targets?)

---

### Comprehensive Error Recovery

**What's missing:**
- No automatic retry logic with exponential backoff
- No transaction rollback mechanism if mid-workflow failure
- No idempotency guarantees (can't safely retry without side effects)
- Limited error context passed between agents

**Blocks:**
- Recovering from transient failures automatically
- Preventing partial state corruption from failed workflows
- Safe retry semantics for user-invoked retries

---

### Rate Limiting and Quota Management

**What's missing:**
- No per-agent rate limiting
- No resource quota enforcement (CPU, memory, API calls)
- No fair-queuing for concurrent workers
- No backpressure mechanism when system is overloaded

**Blocks:**
- Preventing resource exhaustion during parallel execution
- Ensuring responsive service under peak load
- Fair allocation of resources across multiple agents

---

## Test Coverage Gaps

### Shell Script Unit Testing

**Untested area:** Core shell libraries (graph-parser.sh, scope-validator.sh, timeout-manager.sh)

**Files:**
- `scripts/worker/lib/*.sh`
- `scripts/orchestrator/*.sh`

**Risk:**
- Edge cases in string parsing, glob expansion, bash quoting rules
- Bash version compatibility issues (features vary between versions)
- Signal handling during timeouts

**Priority:** High - these are critical path infrastructure

---

### Concurrent State Modification

**Untested area:** Multiple workers modifying GitHub issues simultaneously

**Files:**
- `scripts/orchestrator/dispatch.sh`
- `.claude/skills/worker/lib/parser.sh`

**Risk:**
- Race conditions causing lost updates
- Inconsistent issue state
- Cascading failures when one worker's change affects another

**Priority:** High - Pitfall #3 (shared mutable state) explicitly identified as risk

---

### Scope Escalation Attacks

**Untested area:** Sub-agent scope validation against adversarial constraints

**Files:**
- `scripts/worker/lib/subagent-scope.sh`
- `scripts/worker/lib/scope-validator.sh`

**Risk:**
- Crafted scope definitions could bypass constraint checks
- Sub-agent could gain access to files outside intended scope

**Priority:** Medium-High - security boundary

---

### Long-Running Process Cleanup

**Untested area:** Timeout and termination of sub-agents, resource cleanup after failure

**Files:**
- `scripts/worker/lib/timeout-manager.sh`
- `scripts/worker/spawn-subagent.sh`

**Risk:**
- Leaked processes consuming system resources
- Orphaned file descriptors or locks
- Cascading failures if cleanup fails

**Priority:** Medium - stability and resource management

---

*Concerns audit: 2026-01-29*

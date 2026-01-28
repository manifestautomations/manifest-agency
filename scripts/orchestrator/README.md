# Orchestrator Scripts

Scripts for coordinating Claude workers via GitHub. The Gemini orchestrator uses these scripts to receive CEO intent, decompose into issues, dispatch workers, and aggregate status.

## Overview

The orchestrator is a **stateless coordination layer** between CEO intent and Claude worker execution. All state lives in GitHub (issues, labels, comments). These scripts provide the terminal commands that implement orchestrator operations.

**Design principle:** Gemini skill describes HOW to orchestrate; these scripts execute the work.

**Workflow:**
```
CEO Intent -> Gemini Orchestrator -> Helper Scripts -> GitHub + Workers
                    |
                    +-> intent.sh (classify)
                    +-> decompose.sh (break down)
                    +-> graph.sh (dependencies)
                    +-> dispatch.sh (execute)
                    +-> aggregate.sh (report)
```

## Prerequisites

- **Bash 4.3+**: Required for `wait -n` parallel job control
- **gh CLI 2.x**: GitHub CLI, authenticated with `repo` and `read:project` scopes
- **jq 1.7+**: JSON processing
- **tsort**: Topological sort (GNU coreutils)

Verify installation:
```bash
bash --version  # Should be 4.3+
gh --version    # Should be 2.x
jq --version    # Should be 1.7+
tsort --version # GNU coreutils
gh auth status  # Verify authentication
```

## Scripts

### intent.sh

**Purpose:** Classify CEO input into orchestrator action categories.

**Classifications:**
| Category | Triggers | Action |
|----------|----------|--------|
| DISPATCH | build, implement, create, add, fix, update, deploy, ship, make, configure | Decompose and dispatch |
| STATUS | status, progress, what, how, show, list, report, where, which | Query and aggregate |
| DECISION | blocked, waiting, decide, approve, review, choose, pick, select | Present options |
| CORRECTION | stop, pause, cancel, abort, halt, hold, delay, postpone | Halt workflow |
| CONVERSATION | (default) | Clarify intent |

**Usage:**
```bash
# Classify a message
scripts/orchestrator/intent.sh "build the login page"
# Output: DISPATCH

scripts/orchestrator/intent.sh "what's the status"
# Output: STATUS

scripts/orchestrator/intent.sh "stop all work"
# Output: CORRECTION

# From stdin
echo "show me progress" | scripts/orchestrator/intent.sh
# Output: STATUS
```

**Exit codes:**
- `0`: Classification successful

---

### decompose.sh

**Purpose:** Generate decomposition prompts for Gemini, validate output, and format for issue creation.

**Functions:**
- `generate_decomposition_prompt(intent)` - Creates Gemini prompt with vertical slicing guidelines
- `validate_decomposition(json)` - Validates JSON structure, checks for cycles
- `format_for_creation(json, offset)` - Formats for `gh issue create`
- `format_for_review(json)` - Human-readable summary for CEO

**Usage:**
```bash
# Generate decomposition prompt
scripts/orchestrator/decompose.sh prompt "We need dark mode"

# Validate decomposition JSON
scripts/orchestrator/decompose.sh validate '[
  {"title":"Theme system","summary":"CSS vars and toggle","acceptance":["Toggle works"],"depends_on":[]},
  {"title":"Dashboard dark mode","summary":"Apply theme","acceptance":["Dashboard respects theme"],"depends_on":[1]}
]'

# Format for issue creation (offset 51 means issues start at #52)
scripts/orchestrator/decompose.sh format '[...]' 51

# Format for CEO review
scripts/orchestrator/decompose.sh review '[...]'
```

**Vertical slicing guidelines (embedded in prompts):**
- Each issue 1-4 hours (S or M size)
- All layers in one issue (DB + API + UI)
- Foundation + Features pattern
- Each issue independently shippable

**Exit codes:**
- `0`: Success
- `1`: Validation error (missing fields, invalid dependencies, cycle detected)

---

### graph.sh

**Purpose:** Build and analyze issue dependency graph for execution ordering.

**Functions:**
- `build_dependency_graph(state)` - Extract "Blocked by #N" patterns from issues
- `get_execution_order(state)` - Topological sort for valid execution order
- `get_ready_issues(state)` - Issues with all dependencies resolved
- `detect_cascade(issue)` - Find all issues blocked by a failed issue
- `get_issue_dependencies(issue)` - Get blockers and dependents for one issue
- `validate_graph(state)` - Check for cycles

**Dependency format:** Issues declare dependencies via "Blocked by #N" in the issue body.

**Usage:**
```bash
# Show dependency graph (tsort input format)
scripts/orchestrator/graph.sh graph
# Output:
# 42 45   (issue 45 depends on 42)
# 42 46   (issue 46 depends on 42)

# Get execution order
scripts/orchestrator/graph.sh order
# Output: Issues in valid execution order

# Find ready issues (no unresolved blockers)
scripts/orchestrator/graph.sh ready
# Output: Issue numbers that can be dispatched now

# Detect cascade if issue 42 fails
scripts/orchestrator/graph.sh cascade 42
# Output: Issue numbers blocked by #42

# Get dependencies for specific issue
scripts/orchestrator/graph.sh deps 45
# Output: {"issue":45,"blocked_by":[42],"blocks":[47,48]}

# Validate no cycles
scripts/orchestrator/graph.sh validate
# Output: [ok] Valid DAG with N dependency edges
```

**Exit codes:**
- `0`: Success (or no dependencies)
- `1`: Cycle detected or query error

---

### dispatch.sh

**Purpose:** Worker dispatch with dependency-aware parallel execution.

**Modes:**
- `single`: Dispatch one worker, wait for completion
- `parallel`: Dispatch multiple with concurrency limit
- `dependencies`: Full dependency-ordered dispatch in waves

**Usage:**
```bash
# Dispatch single issue
scripts/orchestrator/dispatch.sh --issue 42

# Dispatch multiple issues in parallel
scripts/orchestrator/dispatch.sh --issues "42 43 44" --max-concurrent 3

# Dispatch all ready issues
scripts/orchestrator/dispatch.sh --all-ready

# Full dependency-aware dispatch
scripts/orchestrator/dispatch.sh --with-dependencies

# Dry run to see what would be dispatched
scripts/orchestrator/dispatch.sh --all-ready --dry-run

# Check current dispatch status
scripts/orchestrator/dispatch.sh --status

# Kill workers on abort (with Ctrl+C)
scripts/orchestrator/dispatch.sh --with-dependencies --force
```

**Options:**
| Option | Description |
|--------|-------------|
| `--issue N` | Dispatch single issue |
| `--issues "N M O"` | Dispatch multiple (parallel) |
| `--all-ready` | Dispatch all issues with no blockers |
| `--with-dependencies` | Full dependency-ordered dispatch |
| `--max-concurrent N` | Limit parallel workers (default: 3) |
| `--dry-run` | Show plan without executing |
| `--status` | Show current dispatch state |
| `--verbose` | Enable debug output |
| `--force` | Kill workers on abort |

**Worker states (GitHub labels):**
| Label | Description | Status |
|-------|-------------|--------|
| `worker:planning` | Analyzing issue | [..] |
| `worker:awaiting-approval` | Plan ready | [??] |
| `worker:executing` | Running | [..] |
| `worker:complete` | Finished | [OK] |
| `worker:partial` | Interrupted | [--] |
| `worker:failed` | Error | [XX] |

**Exit codes:**
- `0`: Success
- `1`: Error or validation failure

---

### aggregate.sh

**Purpose:** Status aggregation with tiered output formats.

**Formats:**
- `oneliner`: Quick count summary
- `table`: Icon-based progress view
- `detailed`: Full JSON with metadata

**Scopes:**
- `active`: Only worker-labeled issues (default)
- `phase`: All open issues
- `all`: All issues including closed

**Usage:**
```bash
# Quick summary
scripts/orchestrator/aggregate.sh --format oneliner
# Output: 3 executing, 2 awaiting approval, 1 blocked

# Progress table
scripts/orchestrator/aggregate.sh --format table
# Output:
# Status | Issue  | Title
# -------|--------|----------------------------------------------
# [??]   | #52    | Foundation - Theme system
# [..]   | #53    | Dark mode for dashboard
# [--]   | #54    | Dark mode for settings

# Full JSON details
scripts/orchestrator/aggregate.sh --format detailed --scope all

# Show cascade impact for failed issue
scripts/orchestrator/aggregate.sh --cascade 42
# Output: Issues blocked by #42 with failure report
```

**Status icons (Windows-compatible):**
| Icon | State |
|------|-------|
| [OK] | Complete |
| [..] | Executing/Planning |
| [??] | Awaiting approval |
| [XX] | Failed |
| [--] | Blocked/Partial |
| [  ] | Open (no worker) |

**Exit codes:**
- `0`: Success

---

## Usage Examples

### End-to-End Workflow

```bash
# 1. CEO says "We need dark mode"
# Orchestrator classifies intent
scripts/orchestrator/intent.sh "We need dark mode"
# Output: DISPATCH

# 2. Generate decomposition for Gemini
scripts/orchestrator/decompose.sh prompt "We need dark mode"
# Gemini returns JSON with vertical slices

# 3. Validate and review decomposition
scripts/orchestrator/decompose.sh validate '$JSON'
scripts/orchestrator/decompose.sh review '$JSON'
# CEO approves

# 4. Create issues (using gh CLI)
scripts/orchestrator/decompose.sh format '$JSON' 51 | jq -r '.[] | .title, .body'
gh issue create --title "Foundation - Theme system" --body "$BODY1"
gh issue create --title "Dark mode for dashboard" --body "$BODY2"
# etc.

# 5. Validate dependency graph
scripts/orchestrator/graph.sh validate
# [ok] Valid DAG with 2 dependency edges

# 6. Dispatch workers
scripts/orchestrator/dispatch.sh --with-dependencies
# Dispatches foundation first, then features when foundation completes

# 7. Monitor status
scripts/orchestrator/aggregate.sh --format table
```

### Check Status

```bash
# Quick status
scripts/orchestrator/aggregate.sh --format oneliner

# Full progress view
scripts/orchestrator/aggregate.sh --format table --scope active

# Detailed JSON for debugging
scripts/orchestrator/aggregate.sh --format detailed
```

### Handle Failure

```bash
# Issue 42 failed - check cascade
scripts/orchestrator/graph.sh cascade 42

# Full failure report
scripts/orchestrator/aggregate.sh --cascade 42

# Retry after fixing
gh issue edit 42 --remove-label "worker:failed"
scripts/worker/execute.sh --issue 42
```

### Dependency Analysis

```bash
# Show all dependencies
scripts/orchestrator/graph.sh graph

# Get execution order
scripts/orchestrator/graph.sh order

# Find ready issues
scripts/orchestrator/graph.sh ready

# Check specific issue
scripts/orchestrator/graph.sh deps 45
```

---

## Integration with Gemini

The Gemini orchestrator skill (`.gemini/skills/orchestrate.md`) invokes these scripts via terminal commands.

### Function Calling to Script Mapping

| Function | Script | Command |
|----------|--------|---------|
| `create_github_issues` | `decompose.sh` | `decompose.sh format '$JSON'` + `gh issue create` |
| `dispatch_workers` | `dispatch.sh` | `dispatch.sh --issues "N M O"` |
| `query_worker_status` | `aggregate.sh` | `aggregate.sh --format FORMAT` |
| `cancel_worker` | `dispatch.sh` | `dispatch.sh --issue N --force` |
| `retry_issue` | `execute.sh` | `scripts/worker/execute.sh --issue N` |

### Typical Gemini Flow

1. **Classify**: `intent.sh "CEO message"` -> route to workflow
2. **Decompose**: `decompose.sh prompt` -> Gemini generates -> `decompose.sh validate`
3. **Create**: `gh issue create` for each issue
4. **Dispatch**: `dispatch.sh --with-dependencies`
5. **Monitor**: `aggregate.sh --format table` periodically
6. **Report**: `aggregate.sh --format oneliner` for CEO updates

---

## Troubleshooting

### "wait: -n: invalid option"
**Cause:** Bash version < 4.3
**Fix:** Update Bash or use `--max-concurrent 1` (sequential)

### "Cycle detected in dependency graph"
**Cause:** Circular dependencies between issues
**Fix:**
1. Run `graph.sh graph` to see edges
2. Identify the cycle
3. Update issue bodies to remove circular dependency

### "gh: command not found"
**Cause:** GitHub CLI not installed
**Fix:** Install from https://cli.github.com/

### "Rate limit exceeded"
**Cause:** Too many GitHub API calls
**Fix:**
1. Wait for rate limit reset: `gh api rate_limit | jq '.resources.core.reset'`
2. Use `--format oneliner` (fewer API calls)
3. Increase polling interval

### Dispatch stuck waiting
**Cause:** Dependencies not completing
**Fix:**
1. Check what's blocked: `dispatch.sh --status`
2. Check dependency graph: `graph.sh graph`
3. Verify blocking issues are progressing

### Workers not starting
**Cause:** Issue missing required sections
**Fix:**
1. Verify issue has `## Summary` and `## Acceptance Criteria` sections
2. Check parser output: Issue body must match expected format

### Lock held by another process
**Cause:** Previous worker crashed or still running
**Fix:**
1. Check if actually running: `dispatch.sh --status`
2. Force override: `scripts/worker/execute.sh --issue N --force`

---

## File Structure

```
scripts/orchestrator/
├── README.md          # This file
├── intent.sh          # Intent classification
├── decompose.sh       # Task decomposition helpers
├── graph.sh           # Dependency graph builder
├── dispatch.sh        # Worker dispatch
└── aggregate.sh       # Status aggregation
```

Dependencies:
- `scripts/worker/execute.sh` - Worker entry point (called by dispatch.sh)
- `scripts/github/*.sh` - GitHub operations (called by workers)

---

## References

- [Gemini Orchestrator Skill](/.gemini/skills/orchestrate.md) - Skill that uses these scripts
- [GitHub Scripts README](/scripts/github/README.md) - GitHub coordination scripts
- [Worker Execute Script](/scripts/worker/execute.sh) - Worker entry point
- [Phase 5 Research](/.planning/phases/05-orchestration/05-RESEARCH.md) - Design decisions

---

*Last updated: 2026-01-28*
*Phase: 05-orchestration*

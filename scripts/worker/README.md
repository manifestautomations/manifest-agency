# Worker Execution Scripts

Scripts for executing GitHub issue work in isolated worktrees with approval workflow, trust-based guardrails, and parallel sub-agent execution.

## Overview

The worker system provides automated execution of GitHub issues with:
- State machine via GitHub labels (survives crashes)
- Approval workflow (exit and resume pattern)
- Trust-based guardrails with automatic rollback
- Parallel sub-agent execution for independent tasks
- Structured JSON logging and audit trails
- Lock-based concurrency control
- Comprehensive error handling

**Design principle:** Worker executes GitHub issues as atomic units of work, creating PRs with full agent metadata and audit trails.

## Prerequisites

- **bash**: v4.3+ (for parallel job control with `wait -n`)
- **gh CLI**: v2.86.0+ ([install](https://cli.github.com/))
- **jq**: v1.7+ for JSON parsing ([install](https://jqlang.github.io/jq/download/))
- **yq**: v4.44+ (mikefarah) for YAML parsing ([install](https://github.com/mikefarah/yq))
- **git**: v2.30+ for worktree support
- **Claude CLI**: For AI execution ([install](https://docs.anthropic.com/claude/docs/quickstart-guide))

Verify installation:
```bash
bash --version     # Should be >= 4.3
gh --version       # Should be >= 2.86.0
jq --version       # Should be >= 1.7
yq --version       # Should be >= 4.44.0 (mikefarah)
git --version      # Should be >= 2.30
claude --version   # Verify Claude CLI installed
```

## Quick Start

1. **Configure worker** (one-time setup):
   ```bash
   # Worker config created during Phase 3
   cat .worker/config.json
   ```

2. **Execute an issue** (basic):
   ```bash
   ./scripts/worker/execute.sh --issue 42
   ```

3. **Review plan** in GitHub issue comment, add thumbs up reaction

4. **Re-run to execute** after approval:
   ```bash
   ./scripts/worker/execute.sh --issue 42
   ```

## Script Reference

### execute.sh

**Purpose:** Main worker entry point - orchestrates complete issue execution lifecycle.

**Features:**
- Label-based state machine (planning → awaiting-approval → executing → complete)
- Automatic parallelization detection via execution graphs
- Trust-based approval workflow
- Isolated worktree creation
- PR creation with agent metadata
- Rollback on failure

**Usage:**
```bash
./scripts/worker/execute.sh --issue NUMBER [OPTIONS]
```

**Required parameters:**
- `--issue NUMBER` - Issue number to execute

**Optional parameters:**
- `--force` - Override stale lock
- `--status` - Check execution status
- `--serial` - Force serial execution (disable sub-agents)

**Examples:**
```bash
# Basic execution (planning phase)
./scripts/worker/execute.sh --issue 42

# After approval (execution phase)
./scripts/worker/execute.sh --issue 42

# Override stale lock after crash
./scripts/worker/execute.sh --issue 42 --force

# Check status
./scripts/worker/execute.sh --issue 42 --status

# Force serial execution (no parallelization)
./scripts/worker/execute.sh --issue 42 --serial
```

**Exit codes:**
- `0` - Success (phase complete)
- `1` - Failure (see issue comment for details)
- `2` - Lock held by another process

---

### spawn-subagent.sh

**Purpose:** Spawn sub-agent for parallel task execution within a wave.

**Usage:**
```bash
./scripts/worker/spawn-subagent.sh \
  --parent-id PARENT_ID \
  --wave-num WAVE_NUM \
  --task-id TASK_ID \
  --task-name "TASK_NAME" \
  --write-scope "file1.ts,file2.ts" \
  --read-scope "file3.ts,file4.ts"
```

**Required parameters:**
- `--parent-id` - Parent agent ID
- `--wave-num` - Wave number
- `--task-id` - Task ID from execution graph
- `--task-name` - Task name/description
- `--write-scope` - Comma-separated list of files this sub-agent can write
- `--read-scope` - Comma-separated list of files this sub-agent can read

**What it does:**
1. Generates unique sub-agent ID
2. Validates scope against parent constraints
3. Creates sub-agent context bundle
4. Spawns Claude with scoped constraints
5. Tracks execution in agent registry
6. Captures PID for monitoring

**Used by:** `execute.sh` when execution graph detected

---

### aggregate-wave.sh

**Purpose:** Aggregate results from completed sub-agents in a wave.

**Features:**
- Structural verification (expected files exist)
- Syntactic verification (code parses)
- Unified wave commit with per-agent summaries
- Rollback on verification failure
- Let-finish pattern for salvage on partial failure

**Usage:**
```bash
source scripts/worker/aggregate-wave.sh

# Aggregate completed wave
aggregate_wave_results WAVE_NUM AGENT_IDS[@]

# Verify wave outputs
verify_wave_outputs TASK_IDS[@]

# Create unified commit
create_wave_commit WAVE_NUM ISSUE_NUM AGENT_IDS[@]

# Rollback failed wave
rollback_wave WAVE_NUM

# Handle wave failure with salvage logic
handle_wave_failure WAVE_NUM FAILED_AGENTS[@] COMPLETED_AGENTS[@]
```

**Functions:**
- `aggregate_wave_results()` - Collect results from completed sub-agents
- `verify_wave_outputs()` - Structural and syntactic verification pipeline
- `create_wave_commit()` - Unified commit with per-agent summaries
- `rollback_wave()` - Unstage and restore to pre-wave state
- `handle_wave_failure()` - Let-finish pattern with salvage assessment

**Used by:** `execute.sh` after wave completion

---

### claude-audit.sh

**Purpose:** Wrapper around Claude CLI with trust-based guardrails and audit logging.

**Features:**
- Trust level enforcement
- Tool restriction based on trust level
- SHA-256 audit chain
- Violation point tracking
- Automatic rollback on trust violations

**Usage:**
```bash
./scripts/worker/claude-audit.sh \
  --prompt "PROMPT" \
  --agent AGENT_NAME \
  [--trust-level LEVEL]
```

**Trust levels:**
- **0** - No trust (read-only, all operations blocked)
- **1** - Basic trust (can read, suggest via diffs)
- **2** - Limited autonomy (can edit with verification) **[default]**
- **3** - Standard autonomy (multi-step plans with checkpoints)
- **4** - Full autonomy (architectural decisions, minimal oversight)

**Trust enforcement:**
- Validates operations against trust-guardrails.yaml patterns
- Logs all actions to audit chain
- Tracks violation points in trust-scores.json
- Automatically decreases trust on violations

**Used by:** `execute.sh` and `spawn-subagent.sh` for all Claude invocations

---

### install-yq.sh

**Purpose:** Install yq (mikefarah) to $HOME/bin for YAML parsing.

**Usage:**
```bash
./scripts/worker/install-yq.sh
```

**What it does:**
- Downloads yq from GitHub releases
- Installs to $HOME/bin (Windows/MINGW64 compatible)
- Adds execute permissions
- Verifies installation

**Exit codes:**
- `0` - Success (yq installed or already present)
- `1` - Installation failed

---

## Library Scripts

### lib/graph-parser.sh

**Purpose:** Extract and validate execution graphs from PLAN.md files.

**Functions:**

**`extract_execution_graph PLAN_FILE`**
- Extracts YAML execution graph from PLAN.md
- Returns YAML content to stdout
- Exit code 0 if graph found, 1 if not (enables serial fallback)

**`validate_dag GRAPH_YAML`**
- Validates directed acyclic graph (no cycles)
- Uses tsort for cycle detection
- Exit code 0 if valid DAG, 1 if cycle detected

**`get_ready_tasks GRAPH_YAML COMPLETED_IDS[@]`**
- Returns task IDs ready to execute
- Ready = all dependencies in completed list
- Enables wave-based parallel execution

**`should_parallelize GRAPH_YAML`**
- Determines if parallelization is worthwhile
- Threshold: 3+ independent tasks OR 2 tasks with total duration > 5min
- Exit code 0 if should parallelize, 1 if should serialize

**Execution Graph Format:**

PLAN.md files can include an execution graph section:

```markdown
## Execution Graph

```yaml
tasks:
  - id: "setup-db"
    name: "Database Setup"
    depends_on: []
    write_scope: ["prisma/schema.prisma", "prisma/migrations/**"]
    read_scope: []
    estimated_duration: "5m"

  - id: "user-model"
    name: "User Model"
    depends_on: ["setup-db"]
    write_scope: ["src/models/user.ts"]
    read_scope: ["prisma/schema.prisma"]
    estimated_duration: "3m"

  - id: "auth-model"
    name: "Auth Model"
    depends_on: ["setup-db"]
    write_scope: ["src/models/auth.ts"]
    read_scope: ["prisma/schema.prisma"]
    estimated_duration: "3m"

  - id: "user-api"
    name: "User API"
    depends_on: ["user-model"]
    write_scope: ["src/api/users.ts", "src/api/routes.ts"]
    read_scope: ["src/models/user.ts"]
    estimated_duration: "4m"
```
```

**Graph fields:**
- `id` - Unique task identifier (used in depends_on)
- `name` - Human-readable task name
- `depends_on` - Array of task IDs that must complete first
- `write_scope` - Files this task can write (supports globs)
- `read_scope` - Files this task can read (optional, inferred if missing)
- `estimated_duration` - Estimated duration (e.g., "5m", "2h")

**Parallelization trigger:**
- Worker detects execution graph in PLAN.md
- Validates DAG (no cycles)
- Checks threshold (3+ independent tasks)
- Spawns sub-agents for parallel waves

**Usage:**
```bash
source scripts/worker/lib/graph-parser.sh

# Extract graph from PLAN.md
GRAPH=$(extract_execution_graph .worker/plans/issue-42-PLAN.md)
if [ $? -eq 0 ]; then
  echo "Graph found"
else
  echo "No graph, use serial execution"
fi

# Validate DAG
if validate_dag "$GRAPH"; then
  echo "Valid DAG"
else
  echo "Cycle detected!"
fi

# Get ready tasks
COMPLETED=("setup-db")
READY=$(get_ready_tasks "$GRAPH" COMPLETED[@])
echo "Ready tasks: $READY"

# Check if should parallelize
if should_parallelize "$GRAPH"; then
  echo "Spawn sub-agents"
else
  echo "Use serial execution"
fi
```

---

### lib/subagent-scope.sh

**Purpose:** Generate sub-agent identities and derive scoped constraints.

**Functions:**

**`generate_agent_id PARENT_ID WAVE_NUM TASK_NAME`**
- Generates hierarchical agent ID
- Format: `{parent_id}/w{wave}-{task_slug}-{short_hash}`
- Example: `worker-a1b2c3/w2-user-model-x7f3`

**`derive_subagent_constraints PARENT_ID TASK_WRITE_SCOPE TASK_READ_SCOPE`**
- Derives scoped constraints from parent and task
- Validates no scope escalation
- Returns JSON constraints for Claude CLI

**`validate_scope_escalation PARENT_SCOPE SUB_SCOPE`**
- Ensures sub-agent scope doesn't exceed parent scope
- Prevents privilege escalation
- Exit code 0 if valid, 1 if escalation detected

**`register_agent AGENT_ID PARENT_ID TASK_ID CONSTRAINTS`**
- Registers agent in `.worker/agents/registry.yaml`
- Tracks active agents for monitoring
- Stores constraints for audit

**Nesting depth limit:** Maximum depth of 2
- Depth 0: Worker (orchestrates phase)
- Depth 1: Sub-agent (executes major task)
- Depth 2: Sub-sub-agent (discovered parallelism, requires approval)
- Depth 3+: Forbidden (prevents deep recursion)

**Usage:**
```bash
source scripts/worker/lib/subagent-scope.sh

# Generate agent ID
AGENT_ID=$(generate_agent_id "worker-a1b2c3" 2 "User Model")
echo $AGENT_ID  # worker-a1b2c3/w2-user-model-x7f3

# Derive constraints
CONSTRAINTS=$(derive_subagent_constraints \
  "worker-a1b2c3" \
  "src/models/user.ts" \
  "prisma/schema.prisma")

# Validate scope
if validate_scope_escalation "$PARENT_SCOPE" "$SUB_SCOPE"; then
  echo "Scope valid"
else
  echo "Scope escalation detected!"
fi

# Register agent
register_agent "$AGENT_ID" "worker-a1b2c3" "user-model" "$CONSTRAINTS"
```

---

### lib/timeout-manager.sh

**Purpose:** Soft-then-hard timeout enforcement with extension requests.

**Functions:**

**`execute_with_timeout COMMAND TIMEOUT_SECONDS AGENT_ID`**
- Executes command with two-stage timeout
- Soft timeout at 80% (SIGTERM - request graceful stop)
- Hard timeout at 100% (SIGKILL - force termination)
- Captures exit code and output

**`request_extension AGENT_ID REASON DURATION_SECONDS`**
- Requests timeout extension
- Validates against extension limits (max 2 per agent, max 120s per extension)
- Requires justification
- Auto-approved for trust level 3+

**`check_extension_limits AGENT_ID`**
- Checks if agent has extensions remaining
- Returns remaining extensions and total time allowed

**Extension bounds:**
- **Max per extension:** 120 seconds
- **Max extensions per agent:** 2
- **Total max extension:** 240 seconds (4 minutes)

**Trust-based approval:**
- Trust 0-1: Manual approval required
- Trust 2: First-time pattern approval
- Trust 3+: Auto-approve extensions
- Trust 4: Full auto-execute

**Soft timeout protocol:**
1. Parent sends warning at 80% of budget
2. Sub-agent completes current atomic operation
3. Sub-agent stages finished work
4. Sub-agent exits with partial_completion status
5. Parent can salvage completed work

**Usage:**
```bash
source scripts/worker/lib/timeout-manager.sh

# Execute with timeout
execute_with_timeout "long-running-task" 300 "worker-a1b2c3/w1-task-x7f3"

# Request extension
if request_extension "worker-a1b2c3/w1-task-x7f3" "Complex migration needs more time" 120; then
  echo "Extension granted"
else
  echo "Extension denied"
fi

# Check limits
check_extension_limits "worker-a1b2c3/w1-task-x7f3"
```

---

### lib/scope-validator.sh

**Purpose:** Validate write scope conflicts before spawning wave.

**Functions:**

**`validate_wave_scopes TASKS_JSON`**
- Pre-flight validation before spawning any agents
- Detects write scope conflicts (same file in multiple tasks)
- Prevents race conditions and merge conflicts
- Exit code 0 if valid, 1 if conflict detected

**`check_scope_conflict FILE_PATH TASKS_WRITE_SCOPES[@]`**
- Checks if file appears in multiple write scopes
- Supports glob pattern matching
- Returns conflicting task IDs

**`expand_glob_pattern GLOB_PATTERN`**
- Expands glob pattern to actual file list
- Used for conflict detection with wildcards

**Write conflict detection:**
- Single writer per file (enforced by scope)
- Shared read context is immutable during wave
- Index files handled via deferred actions (sub-agents report intended exports, parent applies unified update)

**Usage:**
```bash
source scripts/worker/lib/scope-validator.sh

# Validate wave before spawning
TASKS='[
  {"id": "task1", "write_scope": ["src/models/user.ts"]},
  {"id": "task2", "write_scope": ["src/models/auth.ts"]},
  {"id": "task3", "write_scope": ["src/api/users.ts"]}
]'

if validate_wave_scopes "$TASKS"; then
  echo "No conflicts, safe to spawn"
else
  echo "Write conflict detected!"
fi

# Check specific file
check_scope_conflict "src/models/user.ts" WRITE_SCOPES[@]
```

---

## Sub-agent Parallelization

### Overview

Workers can spawn sub-agents for parallel execution of independent tasks. This dramatically reduces execution time for issues with parallelizable work.

**When parallelization triggers:**
1. Worker detects `## Execution Graph` section in PLAN.md
2. Validates DAG (no circular dependencies)
3. Checks threshold (3+ independent tasks OR 2 tasks with total duration > 5min)
4. Pre-flight validation (no write scope conflicts)
5. Spawns sub-agents in parallel waves

**Nesting depth limits:**
- **Depth 0:** Worker (root orchestrator)
- **Depth 1:** Sub-agent (major task execution)
- **Depth 2:** Sub-sub-agent (discovered parallelism during execution)
- **Depth 3+:** Forbidden (prevents deep recursion)

**Agent identity format:**
```
{parent_id}/w{wave}-{task_slug}-{short_hash}
```

Examples:
- `worker-a1b2c3` (root worker)
- `worker-a1b2c3/w2-user-model-x7f3` (sub-agent in wave 2)
- `worker-a1b2c3/w2-user-model-x7f3/w1-validation-q2n5` (sub-sub-agent)

### Trust Level and Approval

Parallelization approval tied to trust level:

| Trust Level | Approval Workflow |
|-------------|-------------------|
| **0-1** | Manual approval required for all parallel structures |
| **2** | Approve first time per pattern, then auto-execute |
| **3** | Auto-approve unless nesting depth > 1 |
| **4** | Full auto-execute, log for audit only |

**Pattern recognition (Trust 2):**
- Approved patterns cached in `.worker/approved-patterns.yaml`
- Includes: task structure, write scopes, dependencies
- Subsequent matches auto-approved
- Human can revoke pattern approval

**Nesting approval (Trust 3):**
- Depth 1 (worker → sub-agent): auto-approved
- Depth 2 (sub-agent → sub-sub-agent): requires approval
- Prevents unbounded recursion

### Execution Flow

**1. Planning phase (serial):**
```bash
./scripts/worker/execute.sh --issue 42
# Worker generates execution plan
# Detects parallelizable tasks
# Posts plan with execution graph to issue
# Waits for approval
```

**2. Approval:**
```
User reviews plan in GitHub issue
User adds thumbs up reaction
```

**3. Execution phase (parallel):**
```bash
./scripts/worker/execute.sh --issue 42
# Worker validates execution graph
# Pre-flight scope validation
# Spawns wave 1 sub-agents (no dependencies)
# Waits for wave 1 completion
# Aggregates wave 1 results
# Spawns wave 2 sub-agents (depend on wave 1)
# Continues until all waves complete
# Creates unified commit with all changes
# Creates PR
```

### Wave-based Execution

**Wave definition:** Set of tasks with all dependencies satisfied.

**Wave execution:**
1. Identify ready tasks (all dependencies completed)
2. Pre-flight validation (no write conflicts)
3. Spawn sub-agents in parallel
4. Track PIDs for monitoring
5. Wait for all in wave to complete
6. Aggregate results
7. Verify outputs (structural → syntactic)
8. On success: continue to next wave
9. On failure: handle with salvage logic

**Dependency traversal:**
- Uses topological sort (tsort) for execution order
- Ensures dependencies satisfied before execution
- Detects circular dependencies at validation time

### Result Aggregation

**After wave completion:**
1. **Collect results** from all sub-agents
2. **Structural verification** - all expected files present
3. **Syntactic verification** - code parses correctly
4. **Create wave commit** - unified commit with per-agent summaries
5. **Continue to next wave** or complete

**Verification pipeline (layered):**
1. **Structural** - All expected outputs present (blocking)
2. **Syntactic** - Code parses successfully (blocking)
   - bash: `bash -n`
   - JavaScript/TypeScript: `node --check`, `tsc --noEmit`
   - Python: `python -m py_compile`
   - JSON: `jq .`
   - YAML: `yq .`

**Commit message format:**
```
feat(scope): summary

Wave N parallel execution:
- [user-model] Implemented user model with validation
- [auth-model] Implemented auth model with JWT support
- [user-api] Implemented user CRUD endpoints

Phase: 06-worker-parallelization | Wave: 2 | Duration: 4m 23s
Worker: worker-a1b2c3
```

### Failure Handling

**Wave failure response:** Let-finish with salvage

1. **Let running agents finish** (no cancellation)
2. **Assess completed work** for independence
3. **Salvage decision:**
   - If completed work passes verification and is independent: Aggregate partial, retry failed only
   - If completed work depends on failed work: Rollback entire wave
4. **Retry logic:**
   - Max 2 retries per agent
   - Max 3 retries per wave
   - After max retries: Escalate to human

**Rollback mechanism:**
- Unstages all wave changes
- Restores to pre-wave state
- No history pollution
- Logs rollback for audit

**Cascade handling:**
- Identifies waves not dependent on failed wave
- Executes unblocked waves in parallel with retry attempts
- Presents options when all remaining waves blocked
- May replan if dependencies can be restructured

**Timeout handling:**
- Soft timeout at 80% (SIGTERM - graceful stop)
- Grace period (20%) for cleanup
- Hard timeout at 100% (SIGKILL - force kill)
- Extensions possible (max 2min, justified, trust-based approval)

### Usage Examples

**Example 1: Create PLAN.md with execution graph**

```markdown
## Execution Plan

### Tasks

1. **Setup database schema** (5 minutes)
   - Create Prisma schema
   - Generate migrations

2. **Implement user model** (3 minutes, depends on task 1)
   - User model with validation
   - User repository

3. **Implement auth model** (3 minutes, depends on task 1)
   - Auth model with JWT
   - Auth repository

4. **Implement user API** (4 minutes, depends on task 2)
   - CRUD endpoints
   - Input validation

## Execution Graph

```yaml
tasks:
  - id: "setup-db"
    name: "Setup database schema"
    depends_on: []
    write_scope: ["prisma/schema.prisma", "prisma/migrations/**"]
    estimated_duration: "5m"

  - id: "user-model"
    name: "Implement user model"
    depends_on: ["setup-db"]
    write_scope: ["src/models/user.ts", "src/repositories/user.ts"]
    read_scope: ["prisma/schema.prisma"]
    estimated_duration: "3m"

  - id: "auth-model"
    name: "Implement auth model"
    depends_on: ["setup-db"]
    write_scope: ["src/models/auth.ts", "src/repositories/auth.ts"]
    read_scope: ["prisma/schema.prisma"]
    estimated_duration: "3m"

  - id: "user-api"
    name: "Implement user API"
    depends_on: ["user-model"]
    write_scope: ["src/api/users.ts", "src/api/routes.ts"]
    read_scope: ["src/models/user.ts", "src/repositories/user.ts"]
    estimated_duration: "4m"
```
```

**Execution:**
- Wave 1: `setup-db` (serial, no dependencies)
- Wave 2: `user-model`, `auth-model` (parallel, both depend on setup-db)
- Wave 3: `user-api` (serial, depends on user-model)

**Total time:** ~11 minutes (vs. 15 minutes serial)

---

**Example 2: Run worker with sub-agent support**

```bash
# First run: Planning
./scripts/worker/execute.sh --issue 42

# Output:
# [worker] Parsing issue #42...
# [worker] Generating execution plan...
# [worker] Execution graph detected with 4 tasks
# [worker] Parallelization threshold met (2 independent tasks in wave 2)
# [worker] Posting plan with execution graph...
# [worker] Awaiting approval

# Review plan in GitHub, add thumbs up

# Second run: Execution with parallelization
./scripts/worker/execute.sh --issue 42

# Output:
# [worker] Approval received - proceeding with execution
# [worker] Execution graph detected - using parallel execution
# [worker] Wave 1: setup-db
# [worker]   Spawning sub-agent: worker-a1b2c3/w1-setup-db-x7f3
# [worker]   Waiting for wave 1 completion...
# [worker]   Wave 1 complete (5m 12s)
# [worker] Wave 2: user-model, auth-model
# [worker]   Spawning sub-agent: worker-a1b2c3/w2-user-model-k3j8
# [worker]   Spawning sub-agent: worker-a1b2c3/w2-auth-model-m9p2
# [worker]   Waiting for wave 2 completion...
# [worker]   Wave 2 complete (3m 45s) - 2 tasks in parallel
# [worker] Wave 3: user-api
# [worker]   Spawning sub-agent: worker-a1b2c3/w3-user-api-r5t1
# [worker]   Waiting for wave 3 completion...
# [worker]   Wave 3 complete (4m 20s)
# [worker] Aggregating results from 4 sub-agents...
# [worker] Verification passed
# [worker] Creating unified commit...
# [worker] Creating PR...
# [worker] Execution complete
#   PR: https://github.com/user/repo/pull/123
#   Duration: 13m 17s (vs. 15m serial)
```

---

**Example 3: Force serial execution**

```bash
# Disable parallelization with --serial flag
./scripts/worker/execute.sh --issue 42 --serial

# Output:
# [worker] Serial execution forced via --serial flag
# [worker] Executing tasks sequentially...
```

---

**Example 4: Check sub-agent status**

```bash
# Check active sub-agents
cat .worker/agents/registry.yaml

# Output:
# agents:
#   - id: worker-a1b2c3/w2-user-model-k3j8
#     parent_id: worker-a1b2c3
#     task_id: user-model
#     status: executing
#     started_at: 2026-01-29T10:15:30Z
#     constraints:
#       write_scope: ["src/models/user.ts"]
#       read_scope: ["prisma/schema.prisma"]
```

---

## Troubleshooting

### Common Errors

**"Cycle detected in execution graph"**

**Cause:** Circular dependency in task dependencies.

**Fix:**
```bash
# Check execution graph for circular references
# Example problematic graph:
# task-a depends_on: [task-b]
# task-b depends_on: [task-a]

# Remove circular dependency:
# Identify which dependency can be removed
# Restructure tasks to be sequential or independent
```

---

**"Write scope conflict detected"**

**Cause:** Multiple tasks in same wave write to the same file.

**Fix:**
```bash
# Check execution graph for overlapping write_scope
# Example conflict:
# task-a: write_scope: ["src/api/routes.ts"]
# task-b: write_scope: ["src/api/routes.ts"]

# Resolution options:
# 1. Add dependency (task-b depends_on: [task-a])
# 2. Split file (routes-users.ts, routes-auth.ts)
# 3. Use deferred action pattern (sub-agents report, parent merges)
```

---

**"Nesting limit reached"**

**Cause:** Sub-agent attempted to spawn sub-sub-agent at depth 2.

**Fix:**
```bash
# Nesting depth limit is 2
# worker (depth 0)
#   └─ sub-agent (depth 1)
#       └─ sub-sub-agent (depth 2)
#           └─ sub-sub-sub-agent (depth 3) ❌ FORBIDDEN

# Resolution:
# 1. Flatten task hierarchy (move tasks to parent level)
# 2. Request approval for discovered parallelism (trust level increase)
# 3. Execute sub-sub-agent work serially within sub-agent
```

---

**"Extension denied"**

**Cause:** Timeout extension request denied due to limits or trust level.

**Fix:**
```bash
# Check extension limits
cat .worker/agents/{agent-id}/timeout.json

# Extension limits:
# - Max 2 extensions per agent
# - Max 120s per extension
# - Trust level 3+ auto-approved
# - Trust level 0-2 requires manual approval

# Resolution:
# 1. Improve agent efficiency (reduce work)
# 2. Increase trust level (if performance warrants)
# 3. Split task into smaller units
# 4. Manually approve extension (if justified)
```

---

**"Stale lock detected"**

**Cause:** Previous worker execution crashed without releasing lock.

**Fix:**
```bash
# Check lock metadata
cat .worker/locks/issue-42.lock/metadata.json

# If process is dead (crash recovery):
./scripts/worker/execute.sh --issue 42 --force

# If process is alive (another worker running):
# Wait for other worker to complete
# OR kill process if stuck
```

---

**"Field cache not found"**

**Cause:** GitHub project field cache missing.

**Fix:**
```bash
# Run bootstrap to create cache
bash scripts/github/project-bootstrap.sh

# Verify cache exists
cat .cache/github/project-fields.json
```

---

**"Worker in unknown state"**

**Cause:** GitHub label state machine in unexpected state.

**Fix:**
```bash
# Check current labels
gh issue view 42 --json labels

# Reset to known state
# Remove worker labels:
gh issue edit 42 --remove-label worker:executing
gh issue edit 42 --remove-label worker:partial
gh issue edit 42 --remove-label worker:failed

# Add planning label to restart:
gh issue edit 42 --add-label worker:planning

# Re-run worker
./scripts/worker/execute.sh --issue 42
```

---

## Configuration

Worker configuration lives in `.worker/config.json`:

```json
{
  "command_timeout_seconds": 600,
  "lock_staleness_threshold_seconds": 1800,
  "github_api_retry_attempts": 3,
  "github_api_retry_backoff_base": 2,
  "github_api_max_rate_limit_wait_seconds": 300
}
```

**Key settings:**
- **command_timeout_seconds** (600): Max time for single command execution
- **lock_staleness_threshold_seconds** (1800): When lock considered stale (30 min)
- **github_api_retry_attempts** (3): Number of retry attempts on API failure
- **github_api_retry_backoff_base** (2): Exponential backoff base (2^n seconds)
- **github_api_max_rate_limit_wait_seconds** (300): Max wait for rate limit (5 min)

## File Structure

```
.worker/
├── config.json                     # Worker configuration
├── locks/                          # Lock directories (gitignored)
│   └── issue-42.lock/
│       └── metadata.json           # Lock metadata
├── logs/                           # JSON event logs (gitignored)
│   └── issue-42-20260129-103045.jsonl
├── agents/                         # Agent registry and state (gitignored)
│   ├── registry.yaml               # Active agent tracking
│   ├── worker-a1b2c3/
│   │   ├── timeout.json            # Timeout state
│   │   └── extensions.json         # Extension requests
│   └── worker-a1b2c3-w1-task-x7f3/
│       ├── timeout.json
│       └── constraints.json        # Scoped constraints
├── approved-patterns.yaml          # Approved parallel patterns (trust 2)
└── plans/                          # Execution plans (future integration)
    └── issue-42-PLAN.md

scripts/worker/
├── execute.sh                      # Main worker entry point
├── spawn-subagent.sh               # Sub-agent spawning
├── aggregate-wave.sh               # Wave result aggregation
├── claude-audit.sh                 # Claude wrapper with guardrails
├── install-yq.sh                   # yq installation script
└── lib/
    ├── graph-parser.sh             # Execution graph YAML extraction and validation
    ├── subagent-scope.sh           # Agent identity and constraint derivation
    ├── timeout-manager.sh          # Soft-then-hard timeout enforcement
    ├── scope-validator.sh          # Write conflict detection
    ├── logger.sh                   # JSON event logging
    ├── lock.sh                     # Lock management
    └── parser.sh                   # Issue body parsing
```

## State Machine

Worker uses GitHub labels as state machine (survives crashes):

| Label | Description | Next States |
|-------|-------------|-------------|
| `worker:planning` | Analyzing issue, generating plan | awaiting-approval |
| `worker:awaiting-approval` | Plan posted, waiting for approval | executing, failed |
| `worker:executing` | Implementing the work | complete, partial, failed |
| `worker:complete` | Work done, PR created | - |
| `worker:partial` | Interrupted during execution | executing (resume) |
| `worker:failed` | Execution error | executing (retry) |

**State flow:**
```
issue created
    │
    v (first run)
┌─────────────┐
│  planning   │ (parsing, generating plan with graph)
└──────┬──────┘
       │ (posts plan + graph)
       v
┌─────────────┐
│  awaiting-  │ (exits, waits for thumbs up)
│  approval   │
└──────┬──────┘
       │ (re-run after approval)
       v
┌─────────────┐
│  executing  │ (parallel waves or serial)
└──────┬──────┘
       │ (creates PR)
       v
┌─────────────┐
│  complete   │ (done)
└─────────────┘

Error states:
├─ partial (interrupted, work incomplete)
└─ failed (error occurred, see comment)
```

## Issue Format

Worker requires structured issue format:

```markdown
## Summary

Brief description of what needs to be implemented.

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3
```

**Required sections:**
- `## Summary` - High-level description
- `## Acceptance Criteria` - Checklist of requirements

Missing sections cause parse error with helpful comment.

## Integration with Scripts

Worker delegates to existing scripts:

**Worktree management:**
- `scripts/worktree-create.sh` - Creates isolated worktree
- `scripts/worktree-remove.sh` - Cleans up after merge

**GitHub operations:**
- `scripts/github/pr-create.sh` - Creates PR with metadata
- `scripts/github/issue-update-status.sh` - Updates project status
- `scripts/github/issue-comment.sh` - Posts progress comments

**Trust guardrails:**
- `.worker/trust-guardrails.yaml` - Trust pattern definitions
- `.worker/violations/` - Violation logs (gitignored)
- `.worker/audit/` - Audit chain (chain.json tracked, logs gitignored)

## References

- [Worker Skill](../../.claude/skills/worker/execute.md)
- [Trust Guardrails](.worker/trust-guardrails.yaml)
- [Phase 03 Context](.planning/phases/03-single-worker/03-CONTEXT.md)
- [Phase 04 Context](.planning/phases/04-trust-guardrails/04-CONTEXT.md)
- [Phase 06 Context](.planning/phases/06-worker-parallelization/06-CONTEXT.md)

---

*Last updated: 2026-01-29*
*Phase: 06-worker-parallelization*

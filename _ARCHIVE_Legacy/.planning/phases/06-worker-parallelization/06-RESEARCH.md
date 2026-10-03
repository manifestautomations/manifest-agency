# Phase 6: Worker Parallelization - Research

**Researched:** 2026-01-28
**Domain:** Bash parallel execution, subprocess management, YAML parsing, process isolation
**Confidence:** HIGH

## Summary

Worker parallelization in bash requires orchestrating multiple independent sub-agents while maintaining isolation, tracking execution, and gracefully handling failures. The foundation from Phase 5 (dispatch.sh with `wait -n` and associative arrays) provides the core parallel job control pattern that Phase 6 extends into hierarchical sub-agent spawning.

The standard approach layers three capabilities: (1) YAML-based dependency graph parsing using yq for explicit parallelization declarations, (2) bash subprocess spawning with environment variable scoping and timeout management for execution isolation, and (3) git worktree isolation for write conflict prevention. This combination enables workers to safely spawn sub-agents, aggregate results, and salvage partial work from failures without complex synchronization primitives.

**Primary recommendation:** Use yq v4.44+ for YAML graph parsing, extend Phase 5's `wait -n` pattern with hierarchical PID tracking in associative arrays, leverage git worktrees for write isolation (already proven in Phase 3), and implement soft-then-hard timeout protocol using bash `timeout` command with SIGTERM → SIGKILL progression.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| yq (mikefarah) | v4.44.1+ | YAML parsing for execution graphs | Lightweight, dependency-free Go binary; jq-like syntax; handles nested structures; already installed in project |
| bash | 4.3+ | Parallel job control with `wait -n` | Native subprocess management; associative arrays; signal handling; already required by Phase 5 |
| timeout (coreutils) | 9.0+ | Process timeout enforcement | Soft-then-hard kill with SIGTERM → SIGKILL; standard on all platforms; exit codes 124 (timeout) / 137 (killed) |
| jq | 1.6+ | JSON manipulation for logging/state | Already used extensively in logger.sh, audit.sh; proven pattern for structured data |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| pstree | standard | Process tree visualization | Debugging hierarchical sub-agents; verifying parent-child relationships |
| ShellCheck | 0.9+ | Bash script linting | Pre-commit verification pipeline; syntax validation |
| git worktree | 2.35+ | Parallel work isolation | Write scope enforcement; already proven in Phase 3 worktree-create.sh |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| yq (mikefarah) | yq (kislyuk - Python) | Python dependency vs Go binary; similar syntax but less portable |
| bash `wait -n` | GNU Parallel | More features but external dependency; overkill for controlled agent spawning |
| timeout command | Custom bash timeout | Reinventing wheel; timeout handles edge cases (cleanup, signal escalation) |
| Associative arrays | Process registry files | Disk I/O overhead; race conditions; arrays are native and fast |

**Installation:**
```bash
# yq already installed via scripts/worker/install-yq.sh
# Verify version
yq --version  # Should be v4.44.1+

# No additional dependencies required
# bash 4.3+, timeout, jq, git already present
```

## Architecture Patterns

### Recommended Project Structure
```
.worker/
├── agents/
│   ├── registry.yaml        # Active/completed agent tracking
│   └── {agent-id}/
│       ├── context.json     # Scoped context bundle
│       ├── constraints.json # Inherited + narrowed constraints
│       └── pid              # Process ID for tracking
├── waves/
│   ├── {wave-id}/
│   │   ├── agents.json      # Wave membership
│   │   ├── start.timestamp
│   │   └── end.timestamp
│   └── approved-patterns.yaml  # Trust level 2+ pattern cache
└── cascade-state.yaml       # Failure recovery coordination

scripts/worker/
├── spawn-subagent.sh        # Core spawning logic
├── aggregate-wave.sh        # Result aggregation
└── lib/
    ├── graph-parser.sh      # YAML extraction from PLAN.md
    ├── scope-validator.sh   # Write conflict detection
    └── timeout-manager.sh   # Soft-then-hard timeout
```

### Pattern 1: YAML Graph Extraction from PLAN.md
**What:** Extract dependency graph embedded as YAML block in PLAN.md
**When to use:** Every worker execution to determine parallelization opportunities

**Example:**
```bash
# Source: yq official docs + Phase 5 dispatch.sh pattern
# Extract YAML block between markers in markdown

extract_execution_graph() {
  local plan_file="$1"

  # Find YAML block under "## Execution Graph" heading
  # Uses sed to extract between ```yaml and ``` markers
  local yaml_block
  yaml_block=$(sed -n '/^## Execution Graph/,/^##/p' "$plan_file" | \
               sed -n '/```yaml/,/```/p' | \
               sed '1d;$d')  # Remove fence markers

  if [ -z "$yaml_block" ]; then
    echo "[info] No execution graph found - will serialize" >&2
    return 1
  fi

  # Parse with yq to validate and extract task list
  echo "$yaml_block" | yq eval '.tasks' -
}

# Get task dependencies
get_task_dependencies() {
  local task_id="$1"
  local yaml_block="$2"

  echo "$yaml_block" | yq eval ".tasks[] | select(.id == \"$task_id\") | .depends_on[]" -
}

# Validate no cycles (tsort pattern from graph.sh)
validate_dag() {
  local yaml_block="$1"

  # Convert to tsort input format (dependency issue)
  local edges
  edges=$(echo "$yaml_block" | yq eval '.tasks[] |
    .id as $task |
    .depends_on[]? |
    "\(.) \($task)"' -)

  if echo "$edges" | tsort >/dev/null 2>&1; then
    return 0  # Valid DAG
  else
    echo "[error] Cycle detected in execution graph" >&2
    return 1
  fi
}
```

### Pattern 2: Hierarchical Agent Identity
**What:** Generate unique hierarchical IDs for sub-agents with depth tracking
**When to use:** Every sub-agent spawn to maintain parent-child relationships

**Example:**
```bash
# Source: CONTEXT.md specification + bash best practices
# Format: {parent_id}/w{wave}-{task_slug}-{short_hash}

generate_agent_id() {
  local parent_id="$1"
  local wave_num="$2"
  local task_name="$3"

  # Slugify task name (lowercase, hyphens)
  local task_slug
  task_slug=$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-')

  # Generate short hash (8 chars from timestamp + PID)
  local short_hash
  short_hash=$(echo "$$-$(date +%s%N)" | sha256sum | cut -c1-8)

  # Construct hierarchical ID
  if [ -z "$parent_id" ]; then
    # Root worker
    echo "worker-${short_hash}"
  else
    # Sub-agent
    echo "${parent_id}/w${wave_num}-${task_slug}-${short_hash}"
  fi
}

# Extract depth from ID
get_agent_depth() {
  local agent_id="$1"

  # Count slashes to determine depth
  local depth
  depth=$(echo "$agent_id" | tr -cd '/' | wc -c)
  echo "$depth"
}

# Enforce max depth of 2
check_nesting_limit() {
  local agent_id="$1"
  local max_depth=2

  local depth
  depth=$(get_agent_depth "$agent_id")

  if [ "$depth" -ge "$max_depth" ]; then
    echo "[error] Maximum nesting depth ($max_depth) reached" >&2
    return 1
  fi

  return 0
}
```

### Pattern 3: Layered Constraint Derivation
**What:** Inherit parent constraints, apply task scope, validate no escalation
**When to use:** Before spawning each sub-agent to ensure constraint safety

**Example:**
```bash
# Source: CONTEXT.md decisions + environment variable scoping research

derive_subagent_constraints() {
  local parent_constraints="$1"  # JSON file path
  local task_declared_scope="$2" # JSON from task definition

  # Load parent constraints (ceiling)
  local parent_read parent_write parent_trust
  parent_read=$(jq -r '.scope.read[]' "$parent_constraints" | tr '\n' ',')
  parent_write=$(jq -r '.scope.write[]' "$parent_constraints" | tr '\n' ',')
  parent_trust=$(jq -r '.trust_level' "$parent_constraints")

  # Apply task-declared scope (narrowing)
  local task_write
  task_write=$(echo "$task_declared_scope" | jq -r '.write_scope[]' | tr '\n' ',')

  # Validate: task write scope must be subset of parent write scope
  local invalid_writes
  invalid_writes=$(comm -13 \
    <(echo "$parent_write" | tr ',' '\n' | sort) \
    <(echo "$task_write" | tr ',' '\n' | sort))

  if [ -n "$invalid_writes" ]; then
    echo "[error] Task scope exceeds parent: $invalid_writes" >&2
    return 1
  fi

  # Generate derived constraints
  jq -n \
    --arg read "$parent_read" \
    --arg write "$task_write" \
    --arg trust "$parent_trust" \
    '{
      scope: {
        read: ($read | split(",") | map(select(. != ""))),
        write: ($write | split(",") | map(select(. != "")))
      },
      trust_level: ($trust | tonumber),
      parent_ceiling: {
        write: ($read | split(",") | map(select(. != "")))
      }
    }'
}

# Detect write scope overlaps between parallel agents
detect_write_conflicts() {
  local wave_agents="$1"  # JSON array of agent constraint files

  # Build map of file -> agents writing to it
  local file_writers=()

  while IFS= read -r constraint_file; do
    local agent_id
    agent_id=$(basename "$(dirname "$constraint_file")")

    local write_files
    write_files=$(jq -r '.scope.write[]' "$constraint_file")

    while IFS= read -r file; do
      if [ -n "$file" ]; then
        file_writers["$file"]+=" $agent_id"
      fi
    done <<< "$write_files"
  done < <(echo "$wave_agents" | jq -r '.[]')

  # Check for multiple writers
  local conflicts=""
  for file in "${!file_writers[@]}"; do
    local writer_count
    writer_count=$(echo "${file_writers[$file]}" | wc -w)
    if [ "$writer_count" -gt 1 ]; then
      conflicts+="File '$file' has multiple writers:${file_writers[$file]}\n"
    fi
  done

  if [ -n "$conflicts" ]; then
    echo -e "[error] Write scope conflicts detected:\n$conflicts" >&2
    return 1
  fi

  return 0
}
```

### Pattern 4: Soft-then-Hard Timeout Protocol
**What:** Graceful timeout with cleanup period before force kill
**When to use:** Every sub-agent spawn to prevent runaway processes

**Example:**
```bash
# Source: timeout command man page + CONTEXT.md timeout strategy
# Uses timeout command with -k (kill delay) for two-stage termination

execute_with_timeout() {
  local time_budget="$1"  # Total time in seconds
  local command="$2"
  local agent_id="$3"

  # Calculate soft timeout (80% of budget)
  local soft_timeout=$((time_budget * 80 / 100))
  # Grace period (20% of budget)
  local grace_period=$((time_budget - soft_timeout))

  echo "[timeout] Soft: ${soft_timeout}s, Grace: ${grace_period}s, Hard: ${time_budget}s"

  # timeout -k sends SIGKILL after grace period if SIGTERM doesn't work
  # Exit codes: 0=success, 124=timeout, 137=killed
  timeout -k "$grace_period" "$soft_timeout" bash -c "$command"
  local exit_code=$?

  case $exit_code in
    0)
      echo "[complete] Agent $agent_id completed within budget"
      return 0
      ;;
    124)
      echo "[timeout] Agent $agent_id soft timeout - cleanup should have occurred"
      log_audit_event "subagent_timeout" \
        --arg agent "$agent_id" \
        --arg timeout_type "soft" \
        --arg duration "$soft_timeout"
      return 124
      ;;
    137)
      echo "[killed] Agent $agent_id force killed after grace period"
      log_audit_event "subagent_killed" \
        --arg agent "$agent_id" \
        --arg timeout_type "hard" \
        --arg duration "$time_budget"
      return 137
      ;;
    *)
      echo "[error] Agent $agent_id failed with exit code $exit_code"
      return $exit_code
      ;;
  esac
}

# Extension request handling (bounded)
request_timeout_extension() {
  local agent_id="$1"
  local current_budget="$2"
  local justification="$3"
  local max_extension=120  # 2 minutes max as per CONTEXT.md

  # Trust level determines auto-approval
  local trust_level="${TRUST_LEVEL:-2}"

  if [ "$trust_level" -ge 3 ]; then
    # Auto-approve up to max extension
    local extension=$((current_budget * 20 / 100))  # 20% more time
    if [ "$extension" -gt "$max_extension" ]; then
      extension=$max_extension
    fi
    echo "$extension"
    return 0
  else
    # Require approval
    echo "[extension] Agent $agent_id requests ${max_extension}s extension: $justification" >&2
    echo "0"  # Denied without approval
    return 1
  fi
}
```

### Pattern 5: Wave-based Result Aggregation
**What:** Collect results from parallel sub-agents, merge without conflicts
**When to use:** After wave completion to create unified commit

**Example:**
```bash
# Source: Phase 5 dispatch.sh pattern + git best practices

aggregate_wave_results() {
  local wave_id="$1"
  local wave_dir=".worker/waves/$wave_id"

  echo "[aggregate] Collecting results from wave $wave_id"

  # Get list of completed agents
  local completed_agents
  completed_agents=$(jq -r '.agents[] | select(.status == "complete") | .id' \
    "$wave_dir/agents.json")

  # Verify structural integrity first
  local verification_failed=false

  for agent_id in $completed_agents; do
    echo "[verify] Checking outputs from $agent_id..."

    # Structural: All expected outputs present
    local expected_outputs
    expected_outputs=$(jq -r '.agents[] | select(.id == "'"$agent_id"'") | .expected_outputs[]' \
      "$wave_dir/agents.json")

    for output in $expected_outputs; do
      if [ ! -f "$output" ]; then
        echo "[error] Missing expected output: $output from $agent_id" >&2
        verification_failed=true
      fi
    done
  done

  if [ "$verification_failed" = true ]; then
    return 1
  fi

  # Stage all changes from completed agents
  echo "[aggregate] Staging changes..."
  for agent_id in $completed_agents; do
    local write_scope
    write_scope=$(jq -r '.agents[] | select(.id == "'"$agent_id"'") | .write_scope[]' \
      "$wave_dir/agents.json")

    for file in $write_scope; do
      if [ -f "$file" ]; then
        git add "$file"
      fi
    done
  done

  # Create wave commit
  local wave_num
  wave_num=$(basename "$wave_id" | grep -oE 'wave-[0-9]+' | grep -oE '[0-9]+')

  create_wave_commit "$wave_num" "$completed_agents"
}

create_wave_commit() {
  local wave_num="$1"
  local completed_agents="$2"

  # Build commit message with per-agent summaries
  local commit_msg="feat(wave-${wave_num}): parallel execution complete

Wave ${wave_num} parallel execution:
"

  while IFS= read -r agent_id; do
    local agent_slug
    agent_slug=$(echo "$agent_id" | grep -oE 'w[0-9]+-[^-]+-' | sed 's/w[0-9]*-//' | sed 's/-$//')

    local agent_summary
    agent_summary=$(jq -r '.agents[] | select(.id == "'"$agent_id"'") | .task_summary' \
      ".worker/waves/wave-${wave_num}/agents.json")

    commit_msg+="- [${agent_slug}] ${agent_summary}
"
  done <<< "$completed_agents"

  # Add metadata
  local duration
  duration=$(jq -r '.duration' ".worker/waves/wave-${wave_num}/end.timestamp")

  commit_msg+="
Phase: 06 | Wave: ${wave_num} | Duration: ${duration}
Worker: ${WORKER_ID}"

  # Commit
  git commit -m "$commit_msg"
}
```

### Anti-Patterns to Avoid
- **Shared state via global variables:** Sub-agents run in separate processes - use files or IPC, not bash globals
- **Unbounded parallelism:** Always respect MAX_CONCURRENT limit to avoid resource exhaustion
- **Ignoring exit codes from wait -n:** Exit codes contain critical failure information - check and handle them
- **Parsing YAML with sed/awk:** Use yq for correctness - YAML has complex edge cases (multi-line strings, escaping)
- **Killing sub-agents immediately on failure:** Let-finish pattern salvages partial work and prevents corruption

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing | Regex-based markdown extraction | yq with proper YAML extraction | Multi-line strings, comments, escaping, nested structures - YAML is deceptively complex |
| Process timeouts | Custom sleep + kill loops | `timeout -k` command | Signal escalation, cleanup periods, race conditions in PID checking |
| Retry with backoff | Linear retry loops | Exponential backoff with jitter | Thundering herd problem, load amplification, standard algorithm proven at scale |
| Dependency DAG validation | Manual cycle detection | tsort (already in Phase 5) | Handles transitive dependencies, cycle detection, proven Unix tool |
| Process tree tracking | Custom PID parent lookup | pstree, /proc filesystem | Kernel maintains authoritative parent-child relationships, handles edge cases |
| Write conflict detection | Timestamp-based locking | Git index + scope validation | Index files, rename operations, partial writes - proper locking is hard |

**Key insight:** Bash subprocess management has decades of accumulated edge cases. The standard tools (`timeout`, `wait -n`, `tsort`) handle signals, race conditions, and cleanup that custom solutions miss. Use them.

## Common Pitfalls

### Pitfall 1: Subshell Variable Isolation Gotcha
**What goes wrong:** Variables set in subshells (background jobs with `&`) don't propagate to parent
**Why it happens:** Each `&` creates a separate process with its own memory space
**How to avoid:** Use files, named pipes, or shared memory for sub-agent → parent communication
**Warning signs:**
```bash
# WRONG - status never updates in parent
for task in $tasks; do
  (
    process_task "$task"
    status="complete"  # Lost when subshell exits
  ) &
done
wait
echo "$status"  # Still empty

# RIGHT - use files
for task in $tasks; do
  (
    process_task "$task"
    echo "complete" > ".worker/agents/$task/status"
  ) &
done
```

### Pitfall 2: Race Condition in PID Tracking
**What goes wrong:** Background job exits before PID is recorded in tracking array
**Why it happens:** `&` returns immediately, but job might finish before next line executes
**How to avoid:** Record PID immediately after `&`, check with `kill -0` before operations
**Warning signs:** "No such process" errors when trying to wait on PIDs
```bash
# WRONG - race condition
spawn_agent "$task" &
sleep 0.1  # Hoping this is enough time
worker_pids[$task]=$!  # Might be too late

# RIGHT - atomic PID capture
spawn_agent "$task" &
local pid=$!
worker_pids[$task]=$pid  # Immediate capture
if ! kill -0 "$pid" 2>/dev/null; then
  echo "[warning] Agent already exited before PID recorded"
fi
```

### Pitfall 3: Timeout Extensions Create Infinite Loops
**What goes wrong:** Unbounded extension requests allow sub-agents to run forever
**Why it happens:** No cap on total extensions granted per agent
**How to avoid:** Track total extensions granted, enforce hard cap (2 extensions max as per CONTEXT.md)
**Warning signs:** Agents requesting extensions repeatedly, never completing
```bash
# WRONG - unbounded extensions
while request_extension; do
  budget=$((budget + extension))
  timeout "$budget" agent  # Could loop forever
done

# RIGHT - bounded extensions
local extension_count=0
local max_extensions=2
while [ "$extension_count" -lt "$max_extensions" ]; do
  if ! request_extension; then break; fi
  budget=$((budget + extension))
  extension_count=$((extension_count + 1))
  timeout "$budget" agent
done
```

### Pitfall 4: Write Scope Validation After Spawn
**What goes wrong:** Detect write conflicts after sub-agents already started, leading to corruption
**Why it happens:** Validation done during execution instead of before wave dispatch
**How to avoid:** Pre-flight validation before spawning any agents in wave
**Warning signs:** Git merge conflicts, partial file writes, data loss
```bash
# WRONG - validate during execution
for agent in $wave_agents; do
  spawn_agent "$agent" &
done
# Conflicts might already be happening...
detect_write_conflicts

# RIGHT - validate before dispatch
if ! detect_write_conflicts "$wave_agents"; then
  echo "[error] Write scope conflicts - aborting wave"
  return 1
fi
# Safe to proceed
for agent in $wave_agents; do
  spawn_agent "$agent" &
done
```

### Pitfall 5: tsort Input Format Confusion
**What goes wrong:** Dependency edges reversed, causing execution in wrong order
**Why it happens:** tsort expects "dependency dependent" but intuitive to write "dependent dependency"
**How to avoid:** Remember tsort format is "A B" means "B depends on A", test with simple case
**Warning signs:** Tasks executing before their dependencies complete
```bash
# Graph.sh shows the correct pattern (line 66-67):
# "Blocked by #N" means task depends on N
# tsort format: "dependency issue" - dependency MUST complete before issue
# Output: "\($dep) \($issue)" where $dep blocks $issue

# WRONG intuition
echo "task1 dependency1" | tsort  # Outputs: dependency1, task1 (backwards!)

# RIGHT - dependency first
echo "dependency1 task1" | tsort  # Outputs: dependency1, task1 (correct)

# When parsing "Task X blocked by Y":
# tsort input should be: "Y X" (Y must complete before X)
```

## Code Examples

Verified patterns from official sources:

### Parallel Wave Dispatch with wait -n
```bash
# Source: Phase 5 dispatch.sh (lines 229-263)
# Pattern: Spawn up to MAX_CONCURRENT, wait for any to complete, spawn next

dispatch_wave() {
  local wave_agents="$1"  # Space-separated agent IDs
  local max_concurrent="${2:-3}"

  # Associative array for PID tracking
  declare -A agent_pids=()
  local -a completed=()
  local -a failed=()

  for agent_id in $wave_agents; do
    # Wait if at concurrency limit
    while [ ${#agent_pids[@]} -ge $max_concurrent ]; do
      # wait -n returns when ANY background job completes
      wait -n 2>/dev/null || true

      # Check which agents completed
      for id in "${!agent_pids[@]}"; do
        local pid="${agent_pids[$id]}"
        if ! kill -0 "$pid" 2>/dev/null; then
          # Agent finished - check exit code
          wait "$pid" 2>/dev/null
          local exit_code=$?

          if [ $exit_code -eq 0 ]; then
            completed+=("$id")
          else
            failed+=("$id")
          fi

          unset agent_pids[$id]
        fi
      done
    done

    # Spawn next agent
    spawn_subagent "$agent_id" &
    agent_pids[$agent_id]=$!
  done

  # Wait for remaining agents
  while [ ${#agent_pids[@]} -gt 0 ]; do
    wait -n 2>/dev/null || true
    # Check completion as above...
  done

  echo "[wave] Completed: ${#completed[@]}, Failed: ${#failed[@]}"
}
```

### yq YAML Extraction from Markdown
```bash
# Source: yq documentation + practical extraction pattern
# Extract YAML block between markdown fences

extract_yaml_from_markdown() {
  local md_file="$1"
  local heading="$2"  # e.g., "## Execution Graph"

  # Extract section between heading and next heading
  local section
  section=$(sed -n "/^${heading}/,/^##/p" "$md_file")

  # Extract YAML block (between ```yaml and ```)
  local yaml_content
  yaml_content=$(echo "$section" | sed -n '/```yaml/,/```/p' | sed '1d;$d')

  if [ -z "$yaml_content" ]; then
    return 1
  fi

  # Validate YAML with yq
  if ! echo "$yaml_content" | yq eval '.' - >/dev/null 2>&1; then
    echo "[error] Invalid YAML in $heading section" >&2
    return 1
  fi

  echo "$yaml_content"
}

# Query specific fields
get_parallel_tasks() {
  local yaml_block="$1"

  # Get tasks with no dependencies or all dependencies met
  echo "$yaml_block" | yq eval '.tasks[] | select(.depends_on == null or (.depends_on | length) == 0) | .id' -
}

get_task_property() {
  local yaml_block="$1"
  local task_id="$2"
  local property="$3"  # e.g., "write_scope", "estimated_duration"

  echo "$yaml_block" | yq eval ".tasks[] | select(.id == \"$task_id\") | .$property" -
}
```

### Salvage Partial Work on Failure
```bash
# Source: GNU Parallel patterns + CONTEXT.md let-finish strategy
# Let running agents complete, assess salvage options

handle_wave_failure() {
  local wave_id="$1"
  local failed_agent="$2"

  echo "[failure] Agent $failed_agent failed - assessing wave state"

  # Let remaining agents finish (let-finish pattern)
  echo "[salvage] Allowing running agents to complete..."
  while [ ${#agent_pids[@]} -gt 0 ]; do
    wait -n 2>/dev/null || true
    # Update completion tracking...
  done

  # Assess salvage options
  local completed_count=${#completed[@]}
  local failed_count=${#failed[@]}

  echo "[salvage] Wave results: $completed_count succeeded, $failed_count failed"

  # Check if succeeded work is independent
  local salvageable=true
  for completed_id in "${completed[@]}"; do
    # Check if any failed agent was a dependency
    local deps
    deps=$(get_task_dependencies "$completed_id" "$execution_graph")

    for dep in $deps; do
      if printf '%s\n' "${failed[@]}" | grep -q "^${dep}$"; then
        echo "[salvage] $completed_id depends on failed $dep - not salvageable"
        salvageable=false
        break
      fi
    done
  done

  if [ "$salvageable" = true ] && [ "$completed_count" -gt 0 ]; then
    echo "[salvage] Keeping $completed_count completed tasks"
    aggregate_partial_wave "$wave_id" "${completed[@]}"

    # Retry only failed tasks
    echo "[retry] Retrying ${failed_count} failed tasks..."
    retry_failed_tasks "$wave_id" "${failed[@]}"
  else
    echo "[salvage] Rolling back entire wave - dependencies broken"
    rollback_wave "$wave_id"
  fi
}

rollback_wave() {
  local wave_id="$1"

  # Unstage all changes from this wave
  local staged_files
  staged_files=$(git diff --cached --name-only)

  if [ -n "$staged_files" ]; then
    echo "[rollback] Unstaging wave changes..."
    git reset HEAD $staged_files

    # Restore to pre-wave state
    git checkout -- $staged_files
  fi

  echo "[rollback] Wave $wave_id rolled back completely"
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Serial task execution | Wave-based parallel dispatch | Phase 5 (2026-01) | Foundation for sub-agent spawning |
| Global process variables | Associative array PID tracking | Phase 5 (2026-01) | Enables hierarchical agent management |
| Manual cycle checking | tsort-based DAG validation | Phase 5 (2026-01) | Reusable for sub-task graphs |
| Python yq (kislyuk) | Go yq (mikefarah) | v4.0 (2020) | Dependency-free, faster, installed in project |
| Custom timeout loops | `timeout -k` command | coreutils 8.0 (2009) | Standard two-stage kill widely adopted |
| Lock files for concurrency | Git worktrees for isolation | Phase 3 (2026-01) | Write conflict prevention through isolation |
| Immediate failure abort | Let-finish with salvage | 2025-2026 trend | Better resource utilization, partial progress |

**Deprecated/outdated:**
- **Python-based yq (kislyuk):** Requires Python dependency, project uses Go-based mikefarah/yq v4.44.1
- **Custom PID tracking in files:** Bash 4.3+ associative arrays are native, faster, no race conditions from filesystem
- **Immediate kill on timeout:** Modern pattern is SIGTERM (cleanup) → grace period → SIGKILL (force)
- **Process-based parallelism limits:** Phase 5 already established MAX_CONCURRENT pattern, extend rather than replace

## Open Questions

Things that couldn't be fully resolved:

1. **Pattern Recognition Heuristics**
   - What we know: Common patterns like "same verb, different targets" suggest parallelization
   - What's unclear: Exact threshold for confidence in automatic pattern detection
   - Recommendation: Start conservative (require explicit graph), collect data, refine heuristics in post-Phase 6 iteration
   - Confidence: LOW - needs real-world usage data

2. **Trust Level 2 Pattern Caching**
   - What we know: CONTEXT.md specifies caching approved patterns for trust level 2+
   - What's unclear: Cache key structure - how to match "similar" parallelization patterns
   - Recommendation: Use structural hash of dependency graph + file scope fingerprint as cache key
   - Confidence: MEDIUM - pattern matching is heuristic, may need tuning

3. **Extension Request Evaluation**
   - What we know: Extensions bounded to 2 minutes max, trust level gates auto-approval
   - What's unclear: Justification quality criteria - what makes a valid extension request
   - Recommendation: Simple heuristic - accept if agent shows progress (files staged), deny if no observable work
   - Confidence: MEDIUM - progress measurement is fuzzy, may need iteration

4. **Wave Branch Isolation**
   - What we know: CONTEXT.md mentions optional wave branches merged to feature branch
   - What's unclear: When to use wave branches vs direct staging - performance vs safety tradeoff
   - Recommendation: Default to staging (simpler), use wave branches only for trust level 0-1 or >5 tasks
   - Confidence: MEDIUM - need to measure git performance with large waves

5. **Cascade State Persistence**
   - What we know: cascade-state.yaml tracks failure recovery
   - What's unclear: Format and recovery protocol after system crash mid-recovery
   - Recommendation: Use same JSONL append-only pattern as audit logs, replay on restart
   - Confidence: HIGH for append-only pattern, MEDIUM for specific recovery steps

## Sources

### Primary (HIGH confidence)
- [mikefarah/yq GitHub](https://github.com/mikefarah/yq) - Official Go-based YAML processor
- [yq Official Documentation](https://mikefarah.gitbook.io/yq) - Core features, syntax, best practices
- [timeout Linux man page](https://man7.org/linux/man-pages/man1/timeout.1.html) - Authoritative timeout command specification
- [Bash Reference Manual - Command Execution Environment](https://www.gnu.org/software/bash/manual/html_node/Command-Execution-Environment.html) - Environment variable scoping
- Phase 5 implementation: dispatch.sh, graph.sh (existing codebase) - Proven `wait -n` pattern, tsort DAG validation
- Phase 3 implementation: worktree-create.sh (existing codebase) - Git worktree isolation pattern

### Secondary (MEDIUM confidence)
- [Baeldung: Bash Parallel Job Control](https://www.baeldung.com/linux/bash-for-loop-parallel) - wait -n patterns verified with man pages
- [Baeldung: Better Retries with Exponential Backoff](https://www.baeldung.com/resilience4j-backoff-jitter) - Industry standard retry patterns
- [Baeldung: pstree Parent/Child Processes](https://www.baeldung.com/linux/pstree-parent-child-processes) - Process tree tracking
- [ShellCheck Documentation](https://www.shellcheck.net/) - Bash script validation tool
- [Git Worktrees for Parallel AI Development (2026)](https://sgryt.com/posts/git-worktree-parallel-ai-development/) - Recent patterns for parallel work isolation
- [Medium: Mastering Git Worktrees with Claude Code](https://medium.com/@dtunai/mastering-git-worktrees-with-claude-code-for-parallel-development-workflow-41dc91e645fe) - AI agent parallelization context

### Tertiary (LOW confidence)
- [GNU Parallel Documentation](https://www.gnu.org/software/bash/manual/html_node/GNU-Parallel.html) - Alternative to wait -n, not adopted but informative
- [AI-driven Bash Scripts Pattern Recognition](https://www.linuxbash.sh/post/ai-driven-bash-scripts-for-pattern-recognition) - Emerging patterns, unverified
- [Apache Airflow DAG Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html) - Task dependency concepts, different domain
- WebSearch results on retry logic, salvage patterns - Multiple sources agree on exponential backoff + jitter, let-finish patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - yq v4.44.1 installed in project, bash 4.3+ verified in Phase 5, timeout is standard coreutil
- Architecture patterns: HIGH - Built directly on Phase 5 proven patterns (wait -n, associative arrays, tsort)
- Don't-hand-roll: HIGH - Each recommendation verified with official documentation or existing implementation
- Common pitfalls: HIGH - Based on bash subshell behavior documented in Bash Reference Manual + observed patterns
- Open questions: MEDIUM to LOW - Pattern recognition and caching need empirical validation

**Research date:** 2026-01-28
**Valid until:** 2026-02-28 (30 days - stable domain, bash and yq mature tools)

**Foundation confidence:** Phase 5 implementations (dispatch.sh, graph.sh) provide HIGH confidence baseline. Phase 6 extends proven patterns rather than introducing new paradigms. Core uncertainty is in heuristics (pattern recognition, cache matching) which can be iterated post-implementation.

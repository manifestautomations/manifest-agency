# Phase 6: Worker Parallelization - Context

**Gathered:** 2026-01-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable workers to spawn sub-agents for parallel execution of independent subtasks. Workers identify parallelizable work, spawn scoped sub-agents, aggregate results, and handle failures gracefully. This phase focuses on the execution machinery — orchestration and dispatch are already complete in Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Parallelization Triggers

**Layered detection approach:**
1. **Explicit declarations first** — Tasks in PLAN.md include `depends_on` fields creating a DAG
2. **Pattern recognition second** — Recognize common parallelizable shapes (same verb/different targets, no file overlap)
3. **Conservative default** — When uncertain, serialize

**Dependency graph location:** Embedded YAML block in PLAN.md under `## Execution Graph` heading
- Single source of truth (graph lives with plan)
- Human-reviewable during plan approval
- Machine-parseable via YAML extraction
- Auditable in git with the prose

**Minimum threshold:** 3+ independent tasks to trigger parallelization
- Exception: 2 tasks allowed if total estimated duration > 5 minutes
- Configurable via `graph.settings.min_parallel_tasks`

**Approval tied to trust level:**
- Trust 0-1: Always require approval of parallel structure
- Trust 2: Approve first time per pattern, then auto-execute
- Trust 3: Approve only if nesting depth > 1
- Trust 4: Auto-execute, log for audit only

### Sub-agent Scoping

**Layered constraint derivation:**
1. Inherit parent constraints (ceiling — cannot exceed)
2. Apply task-declared scope (explicit narrowing)
3. Infer from task if scope missing (automatic narrowing)
4. Validate no constraint exceeds parent (enforcement)

**File scope with collision prevention:**
- Write scopes must not overlap between parallel sub-agents
- Worker validates before spawning wave
- Shared read context is immutable during wave execution

**Context passing:** Scoped context bundles per sub-agent
- Task specifics (always)
- Relevant files (filtered by scope)
- Project conventions (always, they're small)
- Relevant decisions only (filtered by file scope)
- Parent summary (brief orientation)

**Nesting:** Allowed with depth limit of 2
- Depth 0: Worker (orchestrates phase)
- Depth 1: Sub-agent (executes major task)
- Depth 2: Sub-sub-agent (discovered parallelism, always requires approval)
- Depth 3+: Forbidden

**Identity format:** Hierarchical with short hash
```
{parent_id}/w{wave}-{task_slug}-{short_hash}
```
Examples:
- `worker-a1b2c3` (root worker)
- `worker-a1b2c3/w2-user-model-x7f3` (sub-agent)
- `worker-a1b2c3/w2-user-model-x7f3/w1-validation-q2n5` (sub-sub-agent)

### Result Aggregation

**File changes:** Merge with validation
- Single writer per file (enforced by scope)
- Index files handled via deferred actions (sub-agents report intended exports, parent applies unified update)
- Validation after merge: structural → syntactic → semantic → behavioral → integration

**Verification pipeline (layered, each blocking except quality):**
1. Structural — All expected outputs present
2. Syntactic — Code parses successfully
3. Semantic — TypeScript compiles, types check
4. Behavioral — Related tests pass
5. Integration — Combined changes work together
6. Quality — Linting, style (non-blocking, warning only)

**Commit strategy:** Hybrid — stage individually, commit as wave
- During wave: Sub-agents write and stage files, no commits
- After verification: Single wave commit with all changes
- On failure: Unstage and restore, no history pollution
- Optional: Wave branches merged to feature branch for isolation

**Commit message format:**
```
feat({scope}): {summary}

Wave {N} parallel execution:
- [{agent-slug}] {summary}
- [{agent-slug}] {summary}

Phase: {phase} | Wave: {wave} | Duration: {duration}
Worker: {worker_id}
```

### Failure Handling

**Wave failure response:** Let-finish with salvage
- Running sub-agents complete naturally (no cancellation)
- Completed work staged and held for assessment
- Failed work isolated for diagnosis
- Salvage assessment determines next steps

**Recovery strategies:**
- **Retry failed only** — When succeeded work is independent and salvageable
- **Retry full wave** — When dependencies broken by failure
- **Partial proceed** — When failed work is optional
- **Escalate** — After max retries (2 per agent, 3 per wave)

**Cascade handling:** Skip dependent, run unblocked
- Identify waves not dependent on failed wave
- Execute unblocked waves in parallel with retry attempts
- Present human with options when all remaining waves blocked
- Replan if dependencies can be restructured

**Timeout strategy:** Soft-then-hard (graceful degradation)
- Soft timeout at 80% of budget — request graceful stop
- Grace period (20%) for cleanup
- Hard timeout at 100% — force kill if still running
- Extensions possible but bounded (max 2 minutes, justified)

Soft timeout protocol:
1. Parent sends warning with remaining time
2. Sub-agent completes current atomic operation
3. Sub-agent stages finished work
4. Sub-agent exits with partial_completion status

### Claude's Discretion

- Exact graph parsing implementation (YAML extraction method)
- Pattern recognition heuristics for automatic parallelization detection
- Specific retry backoff strategies
- Log format details for parallel execution tracking
- Extension request evaluation criteria

</decisions>

<specifics>
## Specific Ideas

- Execution graph visualization (ASCII art) when presenting parallel structure for approval
- Wave branches pattern: `feature/phase-6-wave-2` merged to main feature branch
- Approved patterns cached in `.worker/approved-patterns.yaml` for trust level 2
- Agent registry in `.worker/agents/registry.yaml` for tracking all active/completed agents
- Cascade state tracking in `cascade-state.yaml` during failure recovery

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-worker-parallelization*
*Context gathered: 2026-01-28*

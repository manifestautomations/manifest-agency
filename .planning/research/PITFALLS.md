# Multi-Workspace Orchestration Pitfalls

**Focus:** Scaling from single-workspace (v1.0) to multi-workspace orchestration (v1.1)
**Researched:** 2026-01-29
**Confidence:** HIGH (verified against 2025-2026 production failures and academic research)

---

## Quick Reference: Top 10 Migration Pitfalls

| # | Pitfall | Severity | Detection Difficulty | Phase to Address |
|---|---------|----------|---------------------|------------------|
| 1 | Context Contamination | CRITICAL | Hard | Phase 1: Foundation |
| 2 | Submodule State Drift | CRITICAL | Medium | Phase 1: Foundation |
| 3 | Priority Starvation | HIGH | Medium | Phase 2: Orchestration |
| 4 | Status Aggregation Staleness | HIGH | Easy | Phase 2: Orchestration |
| 5 | Cross-Project Dependency Cycles | CRITICAL | Hard | Phase 2: Orchestration |
| 6 | Resource Contention Cascades | HIGH | Medium | Phase 3: Execution |
| 7 | Coordination Overhead Explosion | MEDIUM | Easy | Phase 2: Orchestration |
| 8 | Trust Boundary Leakage | CRITICAL | Hard | Phase 1: Foundation |
| 9 | State Synchronization Race Conditions | HIGH | Hard | Phase 3: Execution |
| 10 | Observability Fragmentation | MEDIUM | Medium | Phase 1: Foundation |

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or require reverting to v1.0.

### Pitfall 1: Context Contamination Across Workspaces

**What goes wrong:** Workers operating in one workspace accidentally leak context (file paths, variable names, project-specific conventions, secrets) into another workspace. This violates isolation and can cause incorrect behavior or security breaches.

**Why it happens when scaling from single to multi-workspace:**
- v1.0 workers assume single workspace context; prompts don't explicitly scope
- Shared agent memory or conversation history persists across workspace switches
- Context window includes previous workspace artifacts not explicitly cleared
- Vector store queries not filtered by workspace/tenant ID

**Consequences:**
- Worker applies Project A's coding conventions to Project B
- Secrets or credentials from one project appear in another's commits
- File paths reference wrong workspace (e.g., `../project-a/` in project-b)
- Configuration drift as patterns from one project "infect" others
- Trust violations when workspace A's trust level applied to workspace B

**Warning signs:**
- Commits reference files outside current workspace
- Agent responses mention project names not in current context
- Style/convention inconsistencies that match another project
- `gh` CLI commands targeting wrong repository

**Prevention:**
```
1. HARD CONTEXT RESET between workspace switches
   - Clear conversation history completely
   - Re-inject workspace-specific CLAUDE.md
   - Verify cwd before any operation

2. WORKSPACE ID in every prompt/tool call
   - Include {workspace_id} in system prompt header
   - Tool calls must include workspace scope
   - Validate paths start with expected workspace root

3. NO SHARED MEMORY across workspaces
   - Vector stores partitioned by workspace_id
   - Session state scoped to workspace
   - Trust ledger is per-workspace, not global

4. EXPLICIT ISOLATION TESTS
   - Test: Run task in workspace A, switch to B, verify no leakage
   - Test: Attempt cross-workspace file access, verify rejection
```

**Existing v1.0 gaps to address:**
- Current trust ledger is single file (`.planning/trust-ledger.md`)
- Context handoff protocol doesn't mandate workspace clearing
- No workspace ID in agent spawn commands

**Sources:**
- [Multi-Tenant AI Leakage: Isolation & Security Challenges](https://layerxsecurity.com/generative-ai/multi-tenant-ai-leakage/)
- [Implementing Tenant Isolation - AWS Bedrock](https://aws.amazon.com/blogs/machine-learning/implementing-tenant-isolation-using-agents-for-amazon-bedrock-in-a-multi-tenant-environment/)
- [MCP Security for Multi-Tenant AI Agents](https://prefactor.tech/blog/mcp-security-multi-tenant-ai-agents-explained)

---

### Pitfall 2: Submodule State Drift

**What goes wrong:** Git submodules point to outdated commits, causing workers to operate on stale code while believing they're current. The "detached HEAD" default behavior means workers can make commits that are lost on next update.

**Why it happens when adding submodules to v1.0:**
- v1.0 uses single repo; submodules introduce distributed state
- `git pull` in parent doesn't automatically update submodules
- CI/CD pipelines clone without `--recurse-submodules`
- Workers forget to push submodule changes before parent commit
- Detached HEAD state discards local changes on update

**Consequences:**
- Workers implement features against outdated API versions
- Merge conflicts appear "from nowhere" when submodules finally sync
- Lost commits when submodule updated after local work
- CI passes locally but fails remotely (different submodule states)
- Cross-project changes require coordinated multi-repo commits (hard to review)

**Warning signs:**
- Submodule shows different commit than expected
- `git status` shows submodule as "modified" unexpectedly
- CI failures mentioning "submodule not found" or "version mismatch"
- Commits in submodule not appearing in `git log` of submodule

**Prevention:**
```
1. ALWAYS TRACK BRANCHES, NOT COMMITS
   - Configure: git config -f .gitmodules submodule.<name>.branch <branch>
   - Update via: git submodule update --remote --merge

2. AUTOMATION SCRIPTS for submodule operations
   - Pre-pull hook: git submodule sync && git submodule update --init --recursive
   - Pre-commit hook: Verify submodule commits pushed
   - CI/CD: Always use `git clone --recurse-submodules`

3. SUBMODULE HEALTH CHECK before any work
   - Script: verify-submodule-state.sh
   - Check: no uncommitted changes in submodules
   - Check: submodule HEAD matches expected branch tip

4. PUSH SUBMODULES FIRST
   - git config push.recurseSubmodules on-demand
   - CI blocks parent push if submodule unpushed
```

**Integration with existing v1.0:**
- Add submodule verification to worker startup sequence
- Extend pre-commit hooks to check submodule state
- GitHub Actions workflow needs `submodules: recursive`

**Sources:**
- [Git Submodules - Official Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Git Submodules Best Practices](https://gist.github.com/slavafomin/08670ec0c0e75b500edbaa5d43a5c93c)
- [Fixing Submodule Issues in Git](https://www.mindfulchase.com/explore/troubleshooting-tips/fixing-merge-conflicts,-detached-head,-and-submodule-issues-in-git.html)

---

### Pitfall 3: Cross-Project Dependency Cycles

**What goes wrong:** Project A depends on Project B's component, while Project B depends on Project A's utility. Workers deadlock waiting for each other, or changes cascade infinitely as each update triggers the other.

**Why it happens when adding multi-project orchestration:**
- Single-project v1.0 has clear internal dependencies
- Multi-project introduces implicit cross-repo dependencies
- Submodules can create circular references
- Shared libraries updated in one project break another
- No global dependency graph exists

**Consequences:**
- Workers wait indefinitely for cross-project dependencies
- Change in Project A breaks Project B build, triggering fix in B that breaks A
- Coordination overhead exceeds value of shared code
- Cannot deploy independently (tight coupling)
- "Version hell" when trying to align cross-project versions

**Warning signs:**
- Task blocked "waiting for Project X to complete Y"
- Build failures cascade across multiple projects
- Same shared file modified by multiple projects in same time period
- Circular submodule references in `.gitmodules`

**Prevention:**
```
1. DEPENDENCY GRAPH at orchestration level
   - Map all cross-project dependencies BEFORE assigning work
   - Detect cycles at planning time, not execution time
   - Reject plans that create circular dependencies

2. ACYCLIC ARCHITECTURE enforcement
   - Layer projects: shared-libs <- core <- applications
   - Lower layers never depend on higher layers
   - Review any cross-project import for direction violation

3. VERSIONED INTERFACES for cross-project boundaries
   - Shared libraries have semantic versions
   - Projects pin to specific versions, update deliberately
   - Breaking changes require coordinated release

4. INDEPENDENT DEPLOYABILITY test
   - Each project must be deployable without other projects
   - Cross-project features are integration points, not dependencies
```

**Integration with existing v1.0:**
- Add dependency direction rules to CLAUDE.md
- Orchestrator validates dependency graph before dispatch
- Sub-issue dependencies must not cross projects (or must be explicit)

**Sources:**
- [Multi-Agent Coordination Gone Wrong](https://galileo.ai/blog/multi-agent-coordination-strategies)
- [Distributed Multi-Project Scheduling Research](https://www.tandfonline.com/doi/full/10.1080/01605682.2025.2457655)
- [Monorepo vs Polyrepo Failures](https://medium.com/@Nexumo_/monorepo-vs-polyrepo-code-at-scale-in-2025-9b0743b68b99)

---

### Pitfall 4: Trust Boundary Leakage

**What goes wrong:** A worker operating at Trust Level 3 in Project A switches to Project B where they should be Trust Level 1. Without per-workspace trust enforcement, they execute privileged operations in a project where they haven't earned trust.

**Why it happens when scaling trust system:**
- v1.0 trust ledger is single global file
- Worker spawned for "trusted" project retains trust in "new" project
- Orchestrator doesn't re-verify trust per workspace
- Trust demotion in one project doesn't propagate to others

**Consequences:**
- Untested agent makes architectural decisions in new project
- Rollback history from Project A doesn't protect Project B
- Critical failure in Project B doesn't demote trust in Project A (should it?)
- Human approval requirements bypassed for "trusted" agent in new context

**Warning signs:**
- Worker performs actions above expected trust level
- No approval requested for first operations in new project
- Trust ledger shows one level, but behavior suggests another
- Rollbacks don't trigger trust demotion

**Prevention:**
```
1. PER-WORKSPACE TRUST LEDGERS
   - Each workspace has own .planning/trust-ledger.md
   - Trust level 0 for any agent in new workspace
   - Trust must be earned per-project

2. TRUST CONTEXT in every operation
   - Hook validates: {workspace_id, agent_id, trust_level, operation}
   - Reject operations exceeding workspace-specific trust
   - Log trust level at every significant action

3. CROSS-WORKSPACE TRUST POLICIES
   - Global trust caps per-workspace trust (can't exceed)
   - Workspace trust independent (earned separately)
   - Demotion can be global OR local (configurable)

4. TRUST VERIFICATION at workspace switch
   - Re-read workspace trust ledger
   - Verify agent exists in workspace's history
   - Default to Level 0 if no history
```

**Impact on v1.0 trust system:**
- Trust ledger path becomes: `{workspace}/.planning/trust-ledger.md`
- Worker startup must read workspace-specific ledger
- Demotion triggers need workspace scope

**Sources:**
- [AI Agent Identity & Zero-Trust 2026](https://medium.com/@raktims2210/ai-agent-identity-zero-trust-the-2026-playbook-for-securing-autonomous-systems-in-banks-e545d077fdff)
- [Multi-Tenant Agent Security - Prefactor](https://prefactor.tech/blog/mcp-security-multi-tenant-ai-agents-explained)

---

## High Severity Pitfalls

Mistakes that cause significant delays, require manual intervention, or degrade system reliability.

### Pitfall 5: Priority Starvation

**What goes wrong:** High-priority Project A continuously consumes worker capacity, leaving lower-priority projects starved indefinitely. "Urgent" tasks always jump the queue, preventing "important" work from progressing.

**Why it happens when managing multiple projects:**
- v1.0 implicit single-project priority (everything is "current")
- Multi-project needs explicit priority arbitration
- Priority defined per-project, not globally comparable
- No fairness mechanism ensures minimum progress per project

**Consequences:**
- P2/P3 projects never make progress
- Stakeholders of "lower priority" projects frustrated
- Technical debt accumulates in neglected projects
- Priority inflation (everything becomes P0 to get attention)

**Warning signs:**
- Same projects always in "waiting" state
- Priority levels cluster at P0/P1
- Stakeholder complaints about ignored projects
- No commits in project for extended period despite tasks

**Prevention:**
```
1. GLOBAL PRIORITY with per-project quotas
   - Each project gets minimum worker-hours per period
   - High priority can exceed quota, not eliminate others
   - Starvation alarm: project with no activity > N days

2. AGING PRIORITY
   - Tasks waiting longer get priority boost
   - Prevents indefinite starvation
   - Maximum wait time triggers escalation

3. EXPLICIT FAIRNESS POLICY
   - Define in CLAUDE.md: minimum attention per project
   - Orchestrator enforces during dispatch
   - Visible in briefings: "Project X at risk of starvation"

4. PRIORITY COMPARABILITY
   - P0 in Project A == P0 in Project B
   - Cross-project prioritization at dispatch time
   - Human approval for priority overrides
```

**Integration with existing v1.0:**
- Extend active-projects.md with priority + last-activity
- Briefing generator flags starvation risks
- Orchestrator dispatch includes fairness check

**Sources:**
- [Multi-Project Resource Scheduling - Epicflow](https://www.epicflow.com/blog/managing-resources-in-a-multi-project-environment-common-challenges-and-ways-to-solve-them/)
- [Schedule Conflicts and Prevention](https://www.epicflow.com/blog/schedule-conflicts-their-causes-and-ways-to-prevent-them/)

---

### Pitfall 6: Status Aggregation Staleness

**What goes wrong:** CEO briefing shows status from 6 hours ago because aggregation polling is slow or caching is aggressive. Decisions made on stale data lead to duplicate work or missed blockers.

**Why it happens when aggregating across workspaces:**
- v1.0 status from single source (immediate)
- Multi-workspace requires polling multiple GitHub repos
- Rate limits force caching, caching causes staleness
- Different repos polled at different times (inconsistent snapshot)
- Webhook delivery failures create gaps

**Consequences:**
- CEO assigns work already completed
- Blockers not visible until much later
- Conflicting tasks dispatched (both see "available")
- Trust in system degrades ("briefing was wrong")

**Warning signs:**
- Briefing mentions issues already closed
- Workers report completing tasks "already done"
- Status timestamps significantly older than current time
- Inconsistencies between GitHub UI and briefing

**Prevention:**
```
1. FRESHNESS METADATA in every status report
   - Include: {data_as_of: timestamp, max_staleness: duration}
   - Briefing warns if any source > max_staleness
   - Human sees "data from 2 hours ago" not just status

2. EVENT-DRIVEN over polling where possible
   - GitHub webhooks for issue/PR events
   - Fallback polling with known staleness
   - Hybrid: webhooks + periodic reconciliation

3. CONSISTENT SNAPSHOT strategy
   - Aggregate at single point in time
   - Wait for all sources before generating briefing
   - Or: report per-source timestamps

4. STALENESS ALERTS
   - If any repo unreachable > N minutes: alert
   - If staleness > threshold: flag in briefing
   - If staleness > critical: block decisions requiring fresh data
```

**Integration with existing v1.0:**
- Briefing template adds "Data freshness" section
- GitHub polling script tracks last-successful-poll
- Webhook receiver logs for audit trail

**Sources:**
- [Status Page Aggregation Guide](https://statusgator.com/blog/status-page-aggregation/)
- [Early Outage Detection - StatusGator](https://statusgator.com/features/status-aggregation)
- [Databricks Dashboard Caching](https://docs.databricks.com/aws/en/dashboards/caching)

---

### Pitfall 7: Resource Contention Cascades

**What goes wrong:** Two workers in different projects both need exclusive access to shared resource (e.g., staging environment, test database, deployment slot). One gets it, the other retries, causing cascading delays across multiple projects.

**Why it happens in multi-workspace:**
- v1.0 single project has implicit resource exclusivity
- Multi-project shares: CI runners, staging environments, deployment slots
- No resource reservation system exists
- Retry storms when multiple workers compete

**Consequences:**
- Workers stuck in retry loops burning tokens
- Shared resources become bottleneck
- Cascading delays (Project A delays B delays C)
- Resource exhaustion (all workers waiting, none working)

**Warning signs:**
- High retry counts in worker logs
- Shared resource at 100% utilization
- Multiple projects blocked on same resource
- Latency spikes correlate with multi-project activity

**Prevention:**
```
1. RESOURCE REGISTRY
   - Catalog shared resources with capacity limits
   - Resources: CI runners, staging envs, API quotas, deployment slots
   - Visible to orchestrator for scheduling

2. RESOURCE RESERVATION before dispatch
   - Orchestrator reserves resources before assigning task
   - Reservation has TTL (prevents indefinite hold)
   - Worker confirms or releases reservation

3. RESOURCE-AWARE SCHEDULING
   - Don't dispatch tasks competing for same resource simultaneously
   - Spread resource-heavy tasks across time
   - Priority determines who gets constrained resource

4. BACKOFF and CIRCUIT BREAKER
   - Exponential backoff with jitter for contention
   - Circuit breaker: if resource unavailable > N times, escalate
   - Don't retry indefinitely (cap at 3 attempts)
```

**Integration with existing v1.0:**
- Add `.worker/resources/registry.yaml`
- Pre-dispatch hook checks resource availability
- Worker reports resource acquisition/release

**Sources:**
- [Distributed Multi-Project Scheduling with Resource Failures](https://www.tandfonline.com/doi/full/10.1080/01605682.2025.2457655)
- [Resource Conflicts in Multi-Project Environments](https://www.runn.io/blog/project-resource-conflicts)

---

### Pitfall 8: State Synchronization Race Conditions

**What goes wrong:** Two operations in different workspaces both read shared state, make decisions, then write back. Both reads see old state, both writes succeed, but final state is inconsistent with either operation's intent.

**Why it happens in multi-workspace:**
- v1.0 sequential execution prevents races
- Multi-project parallel execution creates race windows
- GitHub API is eventually consistent, not ACID
- No distributed locking for cross-project operations

**Consequences:**
- Issue assigned to two workers simultaneously
- Project board shows impossible states
- Commits reference issues in wrong state
- Audit trail shows conflicting actions

**Warning signs:**
- Same issue appears in multiple workers' queues
- GitHub API 409 Conflict errors
- State differs between API queries seconds apart
- Operations that "should have been blocked" succeeded

**Prevention:**
```
1. OPTIMISTIC LOCKING with ETags
   - Read includes ETag, write includes If-Match
   - GitHub rejects write if ETag changed
   - Worker retries with fresh read on conflict

2. CLAIM-BASED ASSIGNMENT
   - Atomic test-and-set for issue assignment
   - Use GitHub API assignee + timestamp
   - Worker verifies own claim before proceeding

3. SINGLE WRITER per resource type
   - Only orchestrator modifies cross-project state
   - Workers modify only within their workspace
   - Cross-workspace coordination via orchestrator

4. IDEMPOTENT OPERATIONS
   - Operations safe to retry: create-if-not-exists, set-to-value
   - Avoid: increment, append (race-prone)
   - Design all cross-project ops to be idempotent
```

**Integration with existing v1.0:**
- Extend GitHub coordination to use ETags
- Worker verifies assignment before starting task
- Retry logic includes ETag refresh

**Sources:**
- [Synchronization in Distributed Systems - GeeksforGeeks](https://www.geeksforgeeks.org/distributed-systems/synchronization-in-distributed-systems/)
- [Distributed System Synchronization Methods](https://www.meegle.com/en_us/topics/distributed-system/distributed-system-synchronization-methods)

---

## Moderate Pitfalls

Mistakes that cause delays or require workarounds but are recoverable.

### Pitfall 9: Coordination Overhead Explosion

**What goes wrong:** Adding multi-project coordination creates so much overhead (status syncing, cross-project communication, approval workflows) that throughput decreases despite having "more projects." The coordination cost exceeds the parallelism benefit.

**Why it happens when scaling from v1.0:**
- v1.0 optimized for single-project speed
- Multi-project adds: status aggregation, priority arbitration, context switches
- Each project boundary adds latency
- Orchestrator becomes bottleneck

**Consequences:**
- Total throughput decreases as projects increase
- Most time spent coordinating, not executing
- Simple tasks take longer than in v1.0 single-project
- Team questions value of multi-project system

**Warning signs:**
- Coordination activities > 50% of worker time
- Task latency increases with project count
- Orchestrator queue grows faster than completion
- Workers frequently idle waiting for coordination

**Prevention:**
```
1. MEASURE coordination overhead explicitly
   - Track: time-in-coordination vs time-executing
   - Alert if ratio exceeds threshold (e.g., 30%)
   - Trend analysis: is overhead growing?

2. MINIMIZE cross-project dependencies
   - Prefer independent projects (parallel execution)
   - Shared resources are coordination points (reduce them)
   - Question every cross-project interaction

3. BATCH coordination where possible
   - Aggregate status updates (not one-at-a-time)
   - Batch priority decisions (not per-task)
   - Reduce round-trips

4. THRESHOLD for adding projects
   - Only add project if expected benefit > coordination cost
   - Test with 2 projects before scaling to N
   - Monitor overhead as projects added
```

**Integration with existing v1.0:**
- Add coordination-time metrics to audit log
- Briefing includes overhead trending
- Cap concurrent projects until overhead proven acceptable

**Sources:**
- [Workflow Orchestration Pitfalls](https://avatu.in/blogs/5-common-workflow-orchestration-mistakes-and-ways-to-avoid-them/)
- [Over-Orchestrating Simple Processes](https://appian.com/blog/acp/process-orchestration/enterprise-process-orchestration-mistakes)

---

### Pitfall 10: Observability Fragmentation

**What goes wrong:** Each workspace has its own logs, metrics, and traces. No unified view exists across workspaces, making cross-project debugging nearly impossible and hiding system-wide issues.

**Why it happens in multi-workspace:**
- v1.0 observability designed for single workspace
- Each submodule/workspace has own log paths
- No correlation IDs across workspaces
- Aggregation requires explicit tooling

**Consequences:**
- Cannot trace request across workspace boundaries
- System-wide issues appear as "random project failures"
- Root cause analysis requires manually correlating logs
- Debugging cross-project interactions takes hours

**Warning signs:**
- "It works in Project A but not B" with no visibility into why
- Cross-project issues require manual log correlation
- No single dashboard for system health
- Same problem appears in multiple projects before noticed

**Prevention:**
```
1. UNIFIED LOGGING format across all workspaces
   - Common fields: timestamp, workspace_id, agent_id, trace_id
   - Centralized log aggregation (or federated with common schema)
   - Every log entry includes workspace context

2. CORRELATION IDs for cross-workspace operations
   - Parent operation ID propagates to all child operations
   - Visible in all workspaces involved
   - Query: "show all operations for trace_id=X"

3. AGGREGATED HEALTH DASHBOARD
   - Single view: all workspaces, all agents, key metrics
   - Drill-down to workspace-specific details
   - Alerts roll up from workspace to system level

4. CROSS-WORKSPACE TRACING
   - Distributed tracing (OpenTelemetry) spans workspaces
   - Trace shows: Orchestrator -> Workspace A -> Workspace B
   - Latency attribution across boundaries
```

**Integration with existing v1.0:**
- Standardize log format in `.worker/audit/`
- Add workspace_id to all audit entries
- Create cross-workspace health check script

**Sources:**
- [AI Agent Observability - IBM](https://www.ibm.com/think/insights/ai-agent-observability)
- [Agentic AI Observability 2026](https://www.n-ix.com/ai-agent-observability/)

---

## Migration-Specific Pitfalls

Unique risks when adding multi-workspace to existing v1.0 system.

### Pitfall 11: Backward Compatibility Breaks

**What goes wrong:** v1.1 changes break v1.0 workflows. Existing commands, scripts, or conventions no longer work. Users discover breaks in production, not testing.

**Prevention:**
- Explicit compatibility matrix: what v1.0 features still work
- Migration guide with breaking changes documented
- Feature flags to enable multi-workspace incrementally
- Rollback path to v1.0 behavior if needed

**Warning signs:**
- v1.0 commands fail silently or with cryptic errors
- Documentation no longer matches behavior
- User reports "this used to work"

---

### Pitfall 12: Premature Multi-Project Before Single-Project Maturity

**What goes wrong:** Rushing to add multi-project orchestration before v1.0 single-project workflows are battle-tested. Problems in single-project multiply across many projects.

**Prevention:**
- Milestone: v1.0 must handle 5+ sequential tasks without intervention
- All v1.0 pitfalls (from existing PITFALLS.md) addressed first
- Multi-project is amplifier: it amplifies good AND bad patterns
- Test multi-project with 2 projects before scaling

**Warning signs:**
- Frequent v1.0 failures still occurring
- Trust system not yet calibrated
- Basic workflows require manual intervention

---

### Pitfall 13: Agent Manager Integration Assumptions

**What goes wrong:** Assuming Anti-Gravity Agent Manager handles coordination automatically. Gaps between what Agent Manager provides and what orchestration needs creates silent failures.

**Why this matters for v1.1:**
- Agent Manager is external tool with own opinions
- v1.0 workflows may conflict with Agent Manager patterns
- Integration points unclear until tested
- Documentation may not cover v1.0 integration specifically

**Prevention:**
- Map Agent Manager capabilities to v1.0 requirements explicitly
- Identify gaps early through exploratory testing
- Build adapters where conventions differ
- Don't assume Agent Manager = complete solution

**Warning signs:**
- Agent Manager does X, but v1.0 expects Y
- Unclear which system is "source of truth" for state
- Features work in Agent Manager demo but not with v1.0

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation | Priority |
|-------|----------------|------------|----------|
| **Foundation** | Context contamination (#1) | Hard context reset, workspace ID everywhere | P0 |
| **Foundation** | Trust boundary leakage (#4) | Per-workspace trust ledgers | P0 |
| **Foundation** | Submodule state drift (#2) | Branch tracking, automation scripts | P0 |
| **Foundation** | Observability fragmentation (#10) | Unified logging format | P1 |
| **Orchestration** | Priority starvation (#5) | Fairness policies, aging priority | P1 |
| **Orchestration** | Cross-project cycles (#3) | Dependency graph validation | P0 |
| **Orchestration** | Status staleness (#6) | Freshness metadata, webhooks | P1 |
| **Orchestration** | Coordination overhead (#9) | Overhead metrics, batching | P2 |
| **Execution** | Resource contention (#7) | Resource registry, reservation | P1 |
| **Execution** | State race conditions (#8) | Optimistic locking, idempotency | P1 |
| **Integration** | Agent Manager gaps (#13) | Explicit mapping, adapters | P1 |
| **Integration** | Backward compatibility (#11) | Compatibility matrix, feature flags | P1 |

---

## Critical Success Factors for v1.1

To avoid these pitfalls, the multi-workspace system MUST have:

1. **Workspace isolation enforced at every layer** (prompts, tools, state, trust)
2. **Submodule automation scripts** (update, verify, push)
3. **Per-workspace trust ledgers** (earned separately per project)
4. **Dependency graph validation** (detect cycles before execution)
5. **Priority fairness mechanisms** (no indefinite starvation)
6. **Status freshness tracking** (know age of every data point)
7. **Resource reservation system** (prevent contention cascades)
8. **Optimistic locking for shared state** (race condition prevention)
9. **Unified observability** (trace across workspace boundaries)
10. **Explicit Agent Manager integration mapping** (no assumption gaps)

---

## Validation Checklist Before v1.1 Launch

- [ ] Context isolation test: Run task in A, switch to B, verify no leakage
- [ ] Submodule sync test: Push parent, verify submodule correct in clean clone
- [ ] Trust isolation test: Trust 3 in A, verify Trust 0 in new project B
- [ ] Priority fairness test: P3 project gets attention even with P0 activity
- [ ] Status freshness test: Briefing shows accurate timestamps
- [ ] Resource contention test: Two workers, one shared resource, no deadlock
- [ ] Race condition test: Concurrent assignments to same issue, one wins cleanly
- [ ] Cross-workspace trace test: Operation spanning A and B visible in single trace
- [ ] Backward compatibility test: All v1.0 commands work unchanged
- [ ] Agent Manager integration test: Known gaps documented and handled

---

## Sources

**Multi-Tenant & Isolation:**
- [Multi-Tenant AI Leakage](https://layerxsecurity.com/generative-ai/multi-tenant-ai-leakage/) - Context window bleeding patterns
- [AWS Bedrock Tenant Isolation](https://aws.amazon.com/blogs/machine-learning/implementing-tenant-isolation-using-agents-for-amazon-bedrock-in-a-multi-tenant-environment/) - Tenant ID enforcement
- [MCP Security Multi-Tenant](https://prefactor.tech/blog/mcp-security-multi-tenant-ai-agents-explained) - Protocol-level isolation

**Git Submodules:**
- [Git Submodules Official](https://git-scm.com/book/en/v2/Git-Tools-Submodules) - Detached HEAD behavior
- [Submodules Best Practices](https://gist.github.com/slavafomin/08670ec0c0e75b500edbaa5d43a5c93c) - Automation patterns
- [Reasons to Avoid Submodules](https://blog.timhutt.co.uk/against-submodules/) - Known pain points

**Multi-Agent Coordination:**
- [Multi-Agent Coordination Strategies](https://galileo.ai/blog/multi-agent-coordination-strategies) - Failure patterns
- [Why Multi-Agent Systems Fail](https://arxiv.org/pdf/2503.13657) - Taxonomy of failures
- [Azure AI Agent Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns) - Anti-patterns

**Multi-Project Scheduling:**
- [Distributed Multi-Project Scheduling](https://www.tandfonline.com/doi/full/10.1080/01605682.2025.2457655) - Resource failure handling
- [Multi-Project Resource Planning](https://www.epicflow.com/blog/managing-resources-in-a-multi-project-environment-common-challenges-and-ways-to-solve-them/) - Prioritization
- [Schedule Conflicts Prevention](https://www.epicflow.com/blog/schedule-conflicts-their-causes-and-ways-to-prevent-them/) - Starvation patterns

**Distributed Systems:**
- [Synchronization in Distributed Systems](https://www.geeksforgeeks.org/distributed-systems/synchronization-in-distributed-systems/) - Race conditions
- [Split-Brain Scenarios](https://www.meegle.com/en_us/topics/distributed-system/distributed-system-synchronization) - Consistency issues

**Orchestration Overhead:**
- [Workflow Orchestration Pitfalls](https://avatu.in/blogs/5-common-workflow-orchestration-mistakes-and-ways-to-avoid-them/) - Over-orchestration
- [Enterprise Process Orchestration](https://appian.com/blog/acp/process-orchestration/enterprise-process-orchestration-mistakes) - Coordination tax
- [Monorepo vs Polyrepo](https://medium.com/@Nexumo_/monorepo-vs-polyrepo-code-at-scale-in-2025-9b0743b68b99) - Where complexity shifts

**Observability:**
- [AI Agent Observability - IBM](https://www.ibm.com/think/insights/ai-agent-observability) - Cross-agent tracing
- [Agentic AI Observability 2026](https://www.n-ix.com/ai-agent-observability/) - Platform requirements

---

*Last updated: 2026-01-29*
*Research confidence: HIGH*
*Focus: Migration pitfalls from single-workspace (v1.0) to multi-workspace (v1.1)*

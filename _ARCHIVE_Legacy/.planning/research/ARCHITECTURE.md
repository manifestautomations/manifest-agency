# Architecture: Multi-Workspace Orchestration

**Domain:** Multi-Repo AI Agent Orchestration
**Researched:** 2026-01-29
**Confidence:** MEDIUM-HIGH (based on existing v1.0 codebase analysis + industry patterns)

## Executive Summary

Multi-workspace orchestration extends the existing single-workspace architecture by introducing a **workspace registry** and **cross-workspace dispatch** mechanism. The parent workspace (Manifest Automations) becomes the orchestration hub, with child workspaces (repos as submodules) maintaining their own GSD setup while receiving dispatched work from the parent orchestrator.

The recommended approach uses **repository_dispatch** events for cross-workspace triggering, **parent constraint inheritance** for trust propagation, and **aggregated status polling** via a unified dashboard skill.

---

## Current Architecture (v1.0)

```
┌─────────────────────────────────────────────────────────────────┐
│  CEO (Human)                                                     │
│  └─ Anti-Gravity Mission Control (inbox/briefings)               │
├─────────────────────────────────────────────────────────────────┤
│  GEMINI ORCHESTRATOR (single workspace)                          │
│  └─ Intent classification, task decomposition                    │
│  └─ Dispatch via: scripts/orchestrator/dispatch.sh               │
│  └─ Status via: scripts/orchestrator/aggregate.sh                │
├─────────────────────────────────────────────────────────────────┤
│  GITHUB (coordination layer - single repo)                       │
│  └─ Issues = work items                                          │
│  └─ Projects = kanban state                                      │
│  └─ Labels = worker state machine                                │
├─────────────────────────────────────────────────────────────────┤
│  CLAUDE WORKERS (GSD-enabled)                                    │
│  └─ scripts/worker/execute.sh --issue N                          │
│  └─ Worktrees for isolation                                      │
│  └─ Sub-agents for parallelization                               │
└─────────────────────────────────────────────────────────────────┘
```

**Key v1.0 patterns:**
- GitHub as single source of truth (labels, issues, PRs)
- Exit-and-resume for approvals (no polling)
- Hook-based trust enforcement
- Stateless orchestrator (queries GitHub for state)

---

## Target Architecture (v1.1)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  CEO (Human)                                                              │
│  └─ Anti-Gravity Agent Manager (unified inbox, multi-workspace view)      │
├──────────────────────────────────────────────────────────────────────────┤
│  PARENT WORKSPACE: Manifest Automations                                   │
│  ├─ Gemini Orchestrator (cross-workspace aware)                          │
│  │   └─ Intent classification with workspace targeting                   │
│  │   └─ Workspace registry queries                                       │
│  │   └─ Cross-workspace dispatch coordination                            │
│  ├─ Workspace Registry (.planning/workspaces/registry.yaml)              │
│  │   └─ Registered child workspaces with metadata                        │
│  │   └─ Trust levels per workspace                                       │
│  │   └─ GitHub repo references                                           │
│  ├─ Status Aggregator                                                    │
│  │   └─ Polls child workspace status                                     │
│  │   └─ Unified dashboard generation                                     │
│  │   └─ Inbox message routing                                            │
│  └─ Parent Trust Constraints                                             │
│      └─ Ceiling for all child workspace operations                       │
├──────────────────────────────────────────────────────────────────────────┤
│  CHILD WORKSPACE A: project-alpha (submodule)                            │
│  ├─ Own GSD setup (.claude/skills/, scripts/worker/)                     │
│  ├─ Own GitHub repo (issues, PRs, projects)                              │
│  ├─ Inherited trust constraints from parent                              │
│  └─ Status reporter (exports to parent aggregator)                       │
├──────────────────────────────────────────────────────────────────────────┤
│  CHILD WORKSPACE B: project-beta (submodule)                             │
│  ├─ Own GSD setup                                                        │
│  ├─ Own GitHub repo                                                      │
│  ├─ Inherited trust constraints                                          │
│  └─ Status reporter                                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

### New Component: Workspace Registry

| Responsibility | Inputs | Outputs | Location |
|----------------|--------|---------|----------|
| Track registered child workspaces | Registration commands, submodule discovery | Workspace metadata (path, repo, trust level) | `.planning/workspaces/registry.yaml` |
| Resolve workspace from intent | Natural language workspace reference | Workspace ID and path | Query function |
| Validate workspace health | Workspace path | Health status (GSD present, scripts functional) | Health check script |

**Data structure:**
```yaml
# .planning/workspaces/registry.yaml
version: 1
workspaces:
  project-alpha:
    path: ./projects/project-alpha
    github: owner/project-alpha
    trust_level: 2
    status: active
    last_sync: 2026-01-29T12:00:00Z
    capabilities:
      - gsd
      - worker-parallelization
      - trust-guardrails

  project-beta:
    path: ./projects/project-beta
    github: owner/project-beta
    trust_level: 2
    status: active
    last_sync: 2026-01-29T12:00:00Z
    capabilities:
      - gsd
```

**Boundaries:**
- Does NOT execute work in child workspaces
- Does NOT manage child workspace internal state
- DOES track which workspaces exist and their metadata
- DOES resolve workspace references for dispatch

---

### Modified Component: Orchestrator Skill

**Changes from v1.0:**

| v1.0 Behavior | v1.1 Behavior |
|---------------|---------------|
| Single workspace dispatch | Multi-workspace dispatch with workspace targeting |
| Local issue creation | Issue creation in target workspace's repo |
| Local status aggregation | Cross-workspace status aggregation |
| Implicit single workspace | Explicit workspace selection (defaults to parent) |

**New intent classification patterns:**

| Pattern | Classification | Example |
|---------|---------------|---------|
| `in {workspace}` | DISPATCH with workspace target | "Build auth module in project-alpha" |
| `across all workspaces` | DISPATCH to all | "Update dependencies across all workspaces" |
| `status of {workspace}` | STATUS with workspace filter | "Status of project-beta" |
| `portfolio status` | STATUS aggregated | "Portfolio status" |

**New orchestrator functions:**

```bash
# Dispatch to child workspace
dispatch_to_workspace() {
  local workspace_id="$1"
  local issue_number="$2"

  # Resolve workspace path
  local ws_path=$(get_workspace_path "$workspace_id")
  local ws_repo=$(get_workspace_repo "$workspace_id")

  # Create issue in child repo
  gh issue create --repo "$ws_repo" --title "$TITLE" --body "$BODY"

  # Trigger child workspace worker
  # Option A: Direct invocation (if same machine)
  # Option B: repository_dispatch (if remote)
  # Option C: gh workflow run (if GH Actions runner)
}

# Aggregate status across workspaces
aggregate_portfolio_status() {
  local workspaces=$(list_workspaces)
  local results=""

  for ws in $workspaces; do
    local ws_repo=$(get_workspace_repo "$ws")
    local ws_status=$(query_workspace_status "$ws_repo")
    results+="$ws: $ws_status\n"
  done

  format_portfolio_summary "$results"
}
```

**Boundaries:**
- DOES coordinate work across workspaces
- DOES route issues to correct repos
- DOES aggregate status from multiple repos
- Does NOT execute directly in child workspaces (dispatch only)

---

### New Component: Cross-Workspace Dispatch Mechanism

Three dispatch modes, selected based on workspace configuration:

#### Mode 1: Direct Invocation (Local Submodules)

For child workspaces present as git submodules on the same machine.

```
Parent Orchestrator
    │
    ├─ Resolve workspace path from registry
    ├─ cd to child workspace
    └─ Invoke: scripts/worker/execute.sh --issue N
```

**Pros:** Fastest, no network latency, shared file system
**Cons:** Requires submodules checked out, same machine
**When:** Development/testing, small deployments

```bash
# scripts/orchestrator/dispatch-workspace.sh
dispatch_local() {
  local workspace_id="$1"
  local issue_number="$2"

  local ws_path=$(yq ".workspaces.$workspace_id.path" "$REGISTRY_FILE")

  if [ ! -d "$ws_path" ]; then
    echo "[error] Workspace not found: $ws_path"
    return 1
  fi

  # Execute in child workspace
  (cd "$ws_path" && scripts/worker/execute.sh --issue "$issue_number")
}
```

#### Mode 2: Repository Dispatch (Remote Repos)

For child workspaces in separate repositories with GitHub Actions.

```
Parent Orchestrator
    │
    ├─ Create issue in child repo (gh issue create --repo owner/child)
    ├─ Send repository_dispatch event
    │   └─ POST /repos/owner/child/dispatches
    │   └─ event_type: "worker-dispatch"
    │   └─ client_payload: { issue: N, parent_trace_id: X }
    │
    ▼
Child Repo (GitHub Actions)
    │
    ├─ Workflow triggered by repository_dispatch
    └─ Runs: scripts/worker/execute.sh --issue N
```

**Pros:** Works across organizations, scalable, auditable
**Cons:** Requires GH Actions setup, API latency
**When:** Production, distributed teams, separate orgs

```bash
# scripts/orchestrator/dispatch-workspace.sh
dispatch_remote() {
  local workspace_id="$1"
  local issue_number="$2"

  local ws_repo=$(yq ".workspaces.$workspace_id.github" "$REGISTRY_FILE")
  local trace_id=$(generate_trace_id)

  # Trigger via repository_dispatch
  gh api "repos/$ws_repo/dispatches" \
    --method POST \
    -f event_type="worker-dispatch" \
    -f client_payload="{\"issue\": $issue_number, \"parent_trace_id\": \"$trace_id\"}"

  # Log dispatch for tracking
  log_dispatch "cross_workspace" \
    --arg workspace "$workspace_id" \
    --arg issue "$issue_number" \
    --arg trace_id "$trace_id"
}
```

**Child workflow (in child repo):**
```yaml
# .github/workflows/worker-dispatch.yml
name: Worker Dispatch
on:
  repository_dispatch:
    types: [worker-dispatch]

jobs:
  execute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Execute worker
        run: scripts/worker/execute.sh --issue ${{ github.event.client_payload.issue }}
        env:
          PARENT_TRACE_ID: ${{ github.event.client_payload.parent_trace_id }}
```

#### Mode 3: Workflow Dispatch (Manual/Scheduled)

For child workspaces with existing workflows that accept inputs.

```bash
# Trigger existing workflow with inputs
gh workflow run worker.yml \
  --repo owner/child \
  -f issue_number=42
```

**Recommendation:** Start with Mode 1 (local submodules) for initial development, add Mode 2 (repository_dispatch) for production deployments.

---

### Modified Component: Status Aggregator

**Changes from v1.0:**

| v1.0 | v1.1 |
|------|------|
| Query single repo | Query multiple repos from registry |
| Local issue labels | Remote issue labels via `gh --repo` |
| Single format output | Unified portfolio view + per-workspace drilldown |

**New aggregation function:**

```bash
# scripts/orchestrator/aggregate.sh (extended)
aggregate_portfolio() {
  local format="${1:-table}"
  local workspaces=$(yq '.workspaces | keys | .[]' "$REGISTRY_FILE")

  local portfolio_data=""

  for ws in $workspaces; do
    local ws_repo=$(yq ".workspaces.$ws.github" "$REGISTRY_FILE")
    local ws_status=$(get_workspace_summary "$ws_repo")

    # Collect: executing, awaiting, complete, failed counts
    portfolio_data+=$(format_workspace_row "$ws" "$ws_status")
  done

  case "$format" in
    oneliner) format_portfolio_oneliner "$portfolio_data" ;;
    table)    format_portfolio_table "$portfolio_data" ;;
    detailed) format_portfolio_detailed "$portfolio_data" ;;
  esac
}

get_workspace_summary() {
  local repo="$1"

  # Query issue counts by label
  local executing=$(gh issue list --repo "$repo" --label "worker:executing" --json number --jq 'length')
  local awaiting=$(gh issue list --repo "$repo" --label "worker:awaiting-approval" --json number --jq 'length')
  local complete=$(gh issue list --repo "$repo" --label "worker:complete" --state closed --json number --jq 'length')
  local failed=$(gh issue list --repo "$repo" --label "worker:failed" --json number --jq 'length')

  echo "$executing,$awaiting,$complete,$failed"
}
```

**Portfolio table format:**

```
Portfolio Status
================

Workspace       | Exec | Wait | Done | Fail | Health
----------------|------|------|------|------|--------
project-alpha   |  2   |  1   |  15  |  0   | [OK]
project-beta    |  1   |  0   |   8  |  1   | [--]
manifest-auto   |  0   |  0   |  36  |  0   | [OK]

Totals: 3 executing, 1 awaiting approval, 59 complete, 1 failed
```

---

### Modified Component: Trust Enforcement

**Parent-child trust inheritance:**

```
PRINCIPLE: Child workspace trust cannot exceed parent ceiling.

Parent (Manifest Automations)
├─ Trust Level: 4 (full autonomy)
├─ Can dispatch to children at lower levels
│
├─ Child: project-alpha
│   └─ Trust Level: 2 (limited autonomy)
│   └─ Inherits parent guardrails + own tighter constraints
│
└─ Child: project-beta
    └─ Trust Level: 2 (limited autonomy)
    └─ Inherits parent guardrails + own tighter constraints
```

**Constraint derivation (same pattern as sub-agent scoping):**

```bash
# scripts/worker/lib/workspace-constraints.sh
derive_workspace_constraints() {
  local parent_constraints="$1"
  local workspace_id="$2"

  local ws_trust=$(yq ".workspaces.$workspace_id.trust_level" "$REGISTRY_FILE")
  local parent_trust=$(jq -r '.trust_level' "$parent_constraints")

  # Cannot exceed parent
  if [ "$ws_trust" -gt "$parent_trust" ]; then
    echo "[error] Workspace trust ($ws_trust) exceeds parent ($parent_trust)"
    return 1
  fi

  # Merge constraints (most restrictive wins)
  merge_constraints "$parent_constraints" "$ws_trust"
}
```

**Cross-workspace operation approval:**

From 07-CONTEXT.md, cross-workspace operations are one of the four approval gates:
- Trust promotions
- Critical violations
- Scope access requests
- **Cross-workspace operations** (new for v1.1)

```bash
# Cross-workspace dispatch requires approval at Trust < 3
request_cross_workspace_approval() {
  local source_workspace="$1"
  local target_workspace="$2"
  local operation="$3"

  local trust_level=$(get_current_trust_level)

  if [ "$trust_level" -lt 3 ]; then
    create_approval_request \
      --type "cross_workspace" \
      --source "$source_workspace" \
      --target "$target_workspace" \
      --operation "$operation"

    echo "[approval] Cross-workspace operation requires CEO approval"
    exit 0
  fi

  # Trust 3+ auto-approved with audit log
  log_audit_event "cross_workspace_auto_approved" \
    --arg source "$source_workspace" \
    --arg target "$target_workspace" \
    --arg trust_level "$trust_level"
}
```

---

### New Component: Workspace Bootstrap

Script to register a new child workspace.

```bash
# scripts/workspace/bootstrap.sh
bootstrap_workspace() {
  local workspace_name="$1"
  local workspace_path="$2"
  local github_repo="$3"

  echo "[bootstrap] Registering workspace: $workspace_name"

  # 1. Validate workspace has required structure
  validate_workspace_structure "$workspace_path" || exit 1

  # 2. Add to registry
  yq -i ".workspaces.$workspace_name = {
    \"path\": \"$workspace_path\",
    \"github\": \"$github_repo\",
    \"trust_level\": 2,
    \"status\": \"active\",
    \"last_sync\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
    \"capabilities\": $(detect_capabilities "$workspace_path")
  }" "$REGISTRY_FILE"

  # 3. Initialize parent trust constraints in child
  copy_parent_constraints "$workspace_path"

  # 4. Set up repository_dispatch workflow if not present
  if [ ! -f "$workspace_path/.github/workflows/worker-dispatch.yml" ]; then
    setup_dispatch_workflow "$workspace_path"
  fi

  echo "[bootstrap] Workspace registered: $workspace_name"
}

validate_workspace_structure() {
  local path="$1"

  # Required files
  [ -f "$path/scripts/worker/execute.sh" ] || { echo "[error] Missing execute.sh"; return 1; }
  [ -d "$path/.claude" ] || { echo "[error] Missing .claude directory"; return 1; }

  # Optional but recommended
  [ -f "$path/.planning/PROJECT.md" ] || echo "[warning] Missing PROJECT.md"

  return 0
}

detect_capabilities() {
  local path="$1"
  local caps="[\"gsd\""

  [ -f "$path/scripts/worker/spawn-subagent.sh" ] && caps+=", \"worker-parallelization\""
  [ -f "$path/.claude/skills/worker/lib/hooks.sh" ] && caps+=", \"trust-guardrails\""
  [ -f "$path/.worker/audit/chain.json" ] && caps+=", \"audit-chain\""

  caps+="]"
  echo "$caps"
}
```

---

## Data Flow Patterns

### Pattern 1: CEO Dispatches to Child Workspace

```
CEO (Anti-Gravity)
    │
    ├─ "Build auth module in project-alpha"
    │
    ▼
Orchestrator (Parent)
    │
    ├─ Classify intent: DISPATCH with workspace target
    ├─ Resolve workspace: project-alpha → ./projects/project-alpha
    ├─ Decompose task to issues
    ├─ Request approval for cross-workspace dispatch (if trust < 3)
    │
    ▼
Cross-Workspace Approval (if required)
    │
    ├─ CEO approves via dashboard
    │
    ▼
Dispatch Mechanism
    │
    ├─ Create issue in owner/project-alpha repo
    ├─ If local: cd && execute.sh
    ├─ If remote: repository_dispatch event
    │
    ▼
Child Workspace: project-alpha
    │
    ├─ Worker picks up issue
    ├─ Executes with inherited constraints
    ├─ Creates PR, updates issue labels
    │
    ▼
Status Aggregator (Parent)
    │
    ├─ Polls child repo for label changes
    ├─ Detects completion
    │
    ▼
CEO Inbox
    │
    └─ "Auth module complete in project-alpha, PR #42 ready for review"
```

### Pattern 2: Portfolio Status Query

```
CEO (Anti-Gravity)
    │
    ├─ "Portfolio status"
    │
    ▼
Orchestrator (Parent)
    │
    ├─ Classify intent: STATUS (portfolio scope)
    ├─ Load workspace registry
    │
    ▼
Status Aggregator
    │
    ├─ For each workspace in registry:
    │   ├─ gh issue list --repo {repo} --label "worker:*"
    │   └─ Collect counts: executing, awaiting, complete, failed
    ├─ Aggregate totals
    ├─ Format portfolio table
    │
    ▼
CEO
    │
    └─ Receives unified portfolio view
```

### Pattern 3: Cross-Workspace Failure Cascade

```
Child Workspace A: Worker fails
    │
    ├─ Updates issue with worker:failed label
    │
    ▼
Status Aggregator (Parent, polling)
    │
    ├─ Detects failure in project-alpha #42
    ├─ Checks for cross-workspace dependencies
    │   └─ project-beta #15 depends on project-alpha #42
    │
    ▼
Cascade Handler
    │
    ├─ Labels project-beta #15 as cascade-blocked
    ├─ Creates failure report
    │
    ▼
CEO Inbox (Immediate notification)
    │
    ├─ "[XX] project-alpha #42 failed"
    ├─ "Cascade impact: project-beta #15 blocked"
    └─ "Options: retry, modify, abandon"
```

---

## Integration Points with Existing Components

### Existing Component Modifications

| Component | Current Location | Modification Needed |
|-----------|------------------|---------------------|
| Orchestrator skill | `.gemini/skills/orchestrate.md` | Add workspace targeting in intent classification, cross-workspace dispatch functions |
| Dispatch script | `scripts/orchestrator/dispatch.sh` | Add `--workspace` flag, workspace resolution |
| Aggregate script | `scripts/orchestrator/aggregate.sh` | Add `--portfolio` mode, multi-repo queries |
| Worker execute | `scripts/worker/execute.sh` | Add `PARENT_TRACE_ID` tracking for cross-workspace tracing |
| Trust enforcement | `.claude/skills/worker/lib/hooks.sh` | Add workspace constraint inheritance |
| CEO dashboard skill | `.agent/skills/ceo-dashboard/` | Add portfolio view, per-workspace drilldown |
| Briefing generator | `scripts/worker/generate-briefing.sh` | Add portfolio section to daily briefing |

### New Components to Build

| Component | Location | Purpose |
|-----------|----------|---------|
| Workspace registry | `.planning/workspaces/registry.yaml` | Track registered child workspaces |
| Workspace bootstrap | `scripts/workspace/bootstrap.sh` | Register new child workspaces |
| Workspace health check | `scripts/workspace/health.sh` | Validate workspace structure and connectivity |
| Cross-workspace dispatch | `scripts/orchestrator/dispatch-workspace.sh` | Handle workspace-targeted dispatch |
| Repository dispatch workflow | `.github/workflows/worker-dispatch.yml` | Template for child repos to receive dispatch events |
| Portfolio aggregation | Extension to aggregate.sh | Multi-repo status collection |

---

## Build Order Recommendation

Based on dependencies, recommended implementation order:

### Phase 1: Foundation (Workspace Registry)

**Build first - no dependencies on other new components:**

1. Create workspace registry schema and location
2. Build workspace bootstrap script
3. Build workspace health check
4. Test with single child workspace (manual registration)

**Validation:** Can register a workspace, query its metadata, validate its health.

### Phase 2: Local Dispatch (Mode 1)

**Build second - depends on Phase 1:**

1. Modify dispatch.sh to accept `--workspace` flag
2. Implement workspace path resolution
3. Implement local dispatch (cd && execute.sh)
4. Add workspace targeting to orchestrator skill intent classification

**Validation:** CEO can say "Build X in project-alpha" and work executes in correct workspace.

### Phase 3: Status Aggregation

**Build third - depends on Phase 1, can parallel with Phase 2:**

1. Extend aggregate.sh with `--portfolio` mode
2. Implement multi-repo status queries
3. Add portfolio view to CEO dashboard skill
4. Add portfolio section to daily briefing

**Validation:** "Portfolio status" returns unified view across all registered workspaces.

### Phase 4: Trust Inheritance

**Build fourth - depends on Phase 2:**

1. Implement workspace constraint derivation
2. Add cross-workspace approval gate
3. Integrate with existing approval workflow
4. Add audit logging for cross-workspace operations

**Validation:** Cross-workspace dispatch at Trust < 3 requires approval; Trust 3+ auto-approved with audit.

### Phase 5: Remote Dispatch (Mode 2)

**Build fifth - optional, for production deployments:**

1. Create repository_dispatch workflow template
2. Implement remote dispatch via GitHub API
3. Add trace ID propagation for cross-workspace tracing
4. Implement async completion detection

**Validation:** Can dispatch to child workspace in different GitHub org via repository_dispatch.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Shared Mutable State Between Workspaces

**What:** Using shared files or databases for cross-workspace coordination.
**Why bad:** Race conditions, no audit trail, violates "GitHub as source of truth".
**Instead:** All cross-workspace state in GitHub (issues, labels, comments). Registry is read-only metadata.

### Anti-Pattern 2: Deep Nesting of Workspaces

**What:** Workspaces containing workspaces containing workspaces.
**Why bad:** Exponential complexity, trust inheritance becomes unclear.
**Instead:** Flat structure - parent and children only. No grandchildren.

### Anti-Pattern 3: Bidirectional Dispatch

**What:** Child workspaces dispatching work back to parent or siblings.
**Why bad:** Circular dependencies, unpredictable execution order.
**Instead:** Unidirectional dispatch - parent dispatches to children only. Children report status up.

### Anti-Pattern 4: Tight Coupling to Workspace Structure

**What:** Hardcoding workspace paths or assuming specific directory layout.
**Why bad:** Breaks when workspaces move or change structure.
**Instead:** All workspace references via registry. Path resolution at runtime.

### Anti-Pattern 5: Synchronous Cross-Workspace Blocking

**What:** Parent orchestrator waiting synchronously for child workspace completion.
**Why bad:** Serializes parallel work, wastes orchestrator resources.
**Instead:** Fire-and-forget dispatch with async status polling. Same pattern as v1.0 worker dispatch.

---

## Scalability Considerations

### At 2-5 Workspaces (MVP)

| Concern | Approach |
|---------|----------|
| Registry size | Single YAML file, no optimization needed |
| Status polling | Sequential gh CLI calls per workspace |
| Dispatch latency | Local mode (cd && execute) is instant |
| Trust management | Single parent constraint file |

### At 10-20 Workspaces (Growth)

| Concern | Approach |
|---------|----------|
| Registry size | Split to per-workspace metadata files |
| Status polling | Parallel gh CLI calls (background jobs) |
| Dispatch latency | Repository dispatch for remote workspaces |
| Trust management | Workspace groups with shared constraint templates |

### At 50+ Workspaces (Scale)

| Concern | Approach |
|---------|----------|
| Registry size | Move to GitHub-based registry (repo with workspace manifests) |
| Status polling | GitHub GraphQL API for bulk queries, webhooks for push updates |
| Dispatch latency | Queue-based dispatch with backpressure |
| Trust management | Hierarchical trust groups, automated trust delegation |

---

## Key Architectural Decisions

### Decision 1: Registry Location

**Recommendation:** `.planning/workspaces/registry.yaml` in parent workspace

**Rationale:**
- Consistent with existing `.planning/` pattern for project metadata
- Single source of truth (no database)
- Version controlled (git tracks changes)
- Human readable (YAML, not binary)

### Decision 2: Dispatch Mechanism

**Recommendation:** Local mode first, repository_dispatch for production

**Rationale:**
- Local mode enables rapid development without GitHub Actions setup
- Repository dispatch is industry standard for cross-repo automation
- Both modes use same interface (scripts/orchestrator/dispatch-workspace.sh)

### Decision 3: Status Aggregation Strategy

**Recommendation:** Polling via gh CLI, not webhooks

**Rationale:**
- Consistent with v1.0 approach (stateless orchestrator)
- No webhook infrastructure to maintain
- Works across GitHub organizations
- Polling frequency configurable

### Decision 4: Trust Inheritance Model

**Recommendation:** Parent ceiling with child-specific constraints

**Rationale:**
- Matches v1.0 sub-agent scoping pattern
- Prevents privilege escalation
- Allows per-workspace customization within bounds

### Decision 5: Cross-Workspace Dependency Tracking

**Recommendation:** Explicit in issue bodies, detected by aggregator

**Rationale:**
- Consistent with v1.0 "Blocked by #N" pattern
- Extended to "Blocked by owner/repo#N" for cross-workspace
- Aggregator detects and reports cascade impacts

---

## Sources

**Official Documentation (HIGH confidence):**
- [GitHub Events that trigger workflows](https://docs.github.com/actions/learn-github-actions/events-that-trigger-workflows) - repository_dispatch documentation
- [Azure AI Agent Orchestration Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns) - Dispatcher/coordinator pattern

**Industry Patterns (MEDIUM confidence):**
- [DEV Community: Multi-Agent Systems Guide 2026](https://dev.to/eira-wexford/how-to-build-multi-agent-systems-complete-2026-guide-1io6) - Dispatch patterns
- [InfoQ: Google's Multi-Agent Design Patterns](https://www.infoq.com/news/2026/01/multi-agent-design-patterns/) - Coordination architecture
- [GitKraken Workspaces](https://www.gitkraken.com/features/workspaces) - Multi-repo dashboard patterns
- [GitHub Actions Cross-Repo Triggers](https://medium.com/hostspaceng/triggering-workflows-in-another-repository-with-github-actions-4f581f8e0ceb) - repository_dispatch implementation

**Codebase Analysis (HIGH confidence):**
- `scripts/worker/execute.sh` - Worker invocation pattern
- `scripts/orchestrator/dispatch.sh` - Single-workspace dispatch implementation
- `scripts/worker/spawn-subagent.sh` - Constraint inheritance pattern
- `.gemini/skills/orchestrate.md` - Orchestrator skill structure
- `.planning/phases/06-worker-parallelization/06-CONTEXT.md` - Sub-agent scoping decisions

---

## Quality Gate Checklist

- [x] Integration points clearly identified
- [x] New vs modified components explicit
- [x] Cross-workspace data flow documented
- [x] Build order considers existing dependencies
- [x] Anti-patterns documented with alternatives
- [x] Scalability considerations addressed
- [x] Key architectural decisions with rationale

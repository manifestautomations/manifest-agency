# Phase 2: GitHub Coordination - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

GitHub configured as the authoritative coordination layer for all agent work. Issues serve as work items, PRs represent completed work, Project board visualizes state, all coordination via gh CLI with no proprietary state storage.

</domain>

<decisions>
## Implementation Decisions

### Issue Structure

**Work Claiming:**
- Project custom field "Claimed By" tracks ownership (not GitHub assignees)
- Three methods by phase: self-assign (Phases 2-4), comment-based (fallback), orchestrator assigns (Phase 5+)
- Agents query unclaimed: `Claimed By = empty + Status = Ready`

**Labels:**
| Category | Labels |
|----------|--------|
| Priority | P0-critical, P1-high, P2-medium, P3-low |
| Complexity | XS, S, M, L, XL |
| Agent Type | agent:any, agent:code-reviewer, agent:backend-developer, etc. |
| Phase | phase:1, phase:2, ... phase:7 |
| Type | bug, feature, chore, research |

**Issue Body Template:**
- Summary (one-line description)
- Context (background, links)
- Acceptance Criteria (checkboxes)
- Subtasks (checkboxes)
- Dependencies (Blocked by: #issue links)
- Parent (if subtask)
- Notes (implementation hints, relevant files)

**Status Workflow:**
`Backlog → Ready → Claimed → In Progress → In Review → Done`
- Agent-driven transitions for early states
- Automation for PR-related transitions (open PR → In Review, merge → Done)

### PR Conventions

**PR-to-Issue Linking:**
- `Closes #N` for primary issue (auto-closes on merge)
- `Relates to #N` for tangential issues (link only)
- Branch naming: `<type>/<issue-number>-<short-description>`

**PR Title Format:**
`<type>(<scope>): <description> (#<issue>)`
- Types: feat, fix, chore, docs, refactor, test, style
- Example: `feat(auth): add JWT token refresh (#42)`

**Agent Metadata in PR Description:**
| Field | Purpose |
|-------|---------|
| Agent | Which agent manifest executed |
| Issue | Work item addressed |
| Worktree | Isolation context |
| Duration | Time from claim to PR |
| Model | Actual model used |
| Trust Level | Agent's trust at execution |
| Commits | Atomic commits in PR |

**Required Checks (Phase 2):**
- Linked issue exists
- Agent metadata present
- Tests pass (if tests exist)

**Optional Checks:**
- Human review (configurable per trust level)
- No secrets detected

### Project Board Layout

**Columns (6):**
`Backlog | Ready | Claimed | In Progress | In Review | Done`

**WIP Limits:**
- 1 claimed per agent
- 1 in-progress per agent

**Custom Fields:**
| Field | Type | Purpose |
|-------|------|---------|
| Status | Single Select | Board columns |
| Claimed By | Text | Agent assignment |
| Priority | Single Select | Sort/filter |
| Complexity | Single Select | Effort estimation |
| Agent Type | Single Select | Routing |
| Phase | Single Select | Roadmap grouping |

**Views:**
- All Work (default board) — full kanban, sort by priority
- Ready Queue (table) — Status = Ready, for agent claiming
- By Phase (table) — grouped by phase for roadmap progress

**Archive:**
- Auto-archive after 14 days in Done (GitHub Projects built-in workflow)
- Issue closes on PR merge, stays searchable in repo

### Status Reporting

**Progress Updates:**
- Issue comments (human-readable) with structured HTML comment blocks (machine-parseable)
- Draft PRs show incremental progress
- Structured format allows future tooling to parse

**Comment Format:**
```markdown
<!-- agent:progress -->
| Field | Value |
|-------|-------|
| Agent | `backend-developer` |
| Status | `implementing` |
| Progress | 60% |
| Elapsed | 8m 23s |
| Current Task | Writing unit tests |
| Blockers | None |
<!-- /agent:progress -->
```

**Update Triggers (Required):**
- Claim, Start (worktree created), PR opened, PR ready, Abandon

**Update Triggers (Recommended):**
- Major milestone complete, Blocker encountered/resolved

**Blocker Handling:**
- Add `blocked` label + structured comment with blocker details
- Comment links to blocking issue, explains reason, tags for escalation
- Escalation path: 1h → orchestrator (Phase 5+), 4h → human, 24h → CEO (Phase 7)

**Aggregated Reports:**
- Board summary: Markdown via `gh project item-list` + jq
- Agent completion report: Structured summary per task
- Daily briefing (Phase 7): Completed, In Flight, Blocked, Metrics, Decisions Needed

### Claude's Discretion

- Exact label colors and emoji usage
- Comment emoji conventions (keep consistent)
- Field validation specifics
- Archive retention period (14 days suggested, can adjust)

</decisions>

<specifics>
## Specific Ideas

- Status workflow mirrors the issue lifecycle: Backlog → Ready → Claimed → In Progress → In Review → Done
- Project fields duplicate labels for queryability (`gh project item-list` can filter fields, not labels)
- Structured HTML comments in issues allow machine parsing while keeping human-readable content visible
- Branch naming includes issue number for GitHub auto-linking: `feature/42-add-auth`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-github-coordination*
*Context gathered: 2026-01-27*

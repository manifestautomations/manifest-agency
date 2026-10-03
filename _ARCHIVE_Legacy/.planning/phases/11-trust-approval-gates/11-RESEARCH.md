# Phase 11: Trust & Approval Gates - Research

**Researched:** 2026-01-30
**Domain:** Trust ceiling enforcement, cross-workspace approval workflows, hierarchical constraint validation
**Confidence:** HIGH

## Summary

Phase 11 implements trust ceiling enforcement across workspaces and explicit approval gates for cross-workspace operations. Research reveals that trust ceiling enforcement follows hierarchical constraint patterns from authority-boundary-ledger, where higher privilege levels constrain lower levels mechanically. Approval workflows adapt GitHub issue-based blocking patterns from manual-approval workflows, using exit-and-resume rather than polling. Trust ledger parsing leverages existing bash/jq patterns for markdown table extraction validated in Phase 8.

**Key findings:**
- Hierarchical trust constraints enforce parent ceiling mechanically via pre-dispatch validation (fail-fast before work begins)
- Trust ledger parsing requires markdown table extraction without full markdown parsing (grep + awk patterns proven reliable)
- Approval workflows use exit-and-resume pattern: create GitHub issue, exit script, resume on issue reaction/comment
- Child-to-parent improvement analysis creates "best hiring practices" feedback loop (Phase 11 innovation from user context)
- Stale ledger detection uses event-driven triggers (last cross-workspace dispatch) not time-based (aligns with GitHub coordination pattern)

**Primary recommendation:** Validate trust ceiling before dispatch (dispatch-to-workspace.sh integration point). Use bash/jq to parse trust ledger Current Level field. Block promotion attempts that exceed parent ceiling with actionable diff generation. Integrate with existing approval-workflow.sh for cross-workspace operations at trust level 3+.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash | 4.0+ | Script orchestration and validation | Universal, proven in Phases 8-10 |
| jq | 1.6+ | JSON config parsing and manipulation | Standard for .worker/config.json operations |
| Git | 2.13+ | Issue creation via gh CLI for approvals | GitHub as coordination layer (v1.0 pattern) |
| grep/awk | GNU | Markdown table parsing from ledgers | Lightweight, reliable for structured tables |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| gh CLI | 2.0+ | GitHub issue creation and reactions | Approval workflow coordination |
| sed | GNU | Template substitution for improvement tasks | GitHub issue body generation |
| diff | GNU | Generate actionable diffs for improvements | Parent workspace enhancement analysis |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Markdown parsing library | grep/awk patterns | Libraries add dependencies; tables are regular enough for awk |
| Time-based staleness | Event-driven triggers | Event-driven matches actual usage patterns better |
| Runtime permission checks | Pre-dispatch validation | Fail fast prevents wasted work in unhealthy workspaces |
| Custom approval UI | GitHub issue reactions | GitHub reactions fit existing coordination layer pattern |

**Installation:**
```bash
# All core tools already present in Phase 8-10 environment
# No additional dependencies required
```

## Architecture Patterns

### Recommended Integration Points

```
dispatch-to-workspace.sh
├── Step 1: Resolve workspace name        [EXISTING]
├── Step 2: Check workspace health        [EXISTING]
├── Step 3: Get trust ceiling             [EXISTING - extract from config]
├── Step 3.5: VALIDATE CHILD TRUST ← NEW
│   └── Read child ledger Current Level
│   └── Compare to parent ceiling
│   └── Block if child > parent
│   └── Generate improvement analysis if blocked
├── Step 4: CHECK APPROVAL REQUIREMENT ← NEW
│   └── If trust level >= 3: Request approval
│   └── Create GitHub issue with context
│   └── Exit and await reaction
├── Step 5: Log dispatch event            [EXISTING]
├── Step 6: Record frecency access        [EXISTING]
└── Step 7: Output dispatch confirmation  [EXISTING]
```

### Pattern 1: Trust Ledger Parsing (Markdown Table Extraction)

**What:** Extract Current Level from trust ledger markdown table without full markdown parsing
**When to use:** Trust ceiling validation, ledger staleness checks
**Example:**
```bash
# Source: Adapted from workspace-health.sh header validation pattern
# Extract "Current Level" value from trust ledger table
# Format: | **Current Level** | N (Trust Name) |

get_current_trust_level() {
    local ledger_path="$1"

    if [[ ! -f "$ledger_path" ]]; then
        echo "0"  # Default to zero trust if ledger missing
        return 0
    fi

    # Extract level from table row (handle both formats)
    # Format 1: | **Current Level** | 2 (Limited Autonomy) |
    # Format 2: | **Current Level** | 2 |
    local level
    level=$(grep -i "Current Level" "$ledger_path" | \
            awk -F'|' '{print $3}' | \
            tr -d ' ' | \
            grep -oE '^[0-4]')

    # Validate extracted level
    if [[ "$level" =~ ^[0-4]$ ]]; then
        echo "$level"
    else
        echo "0"  # Default to zero trust if parse fails
    fi
}

# Extract trust ceiling (same pattern)
get_trust_ceiling() {
    local ledger_path="$1"

    if [[ ! -f "$ledger_path" ]]; then
        echo "4"  # Default to max if no constraint
        return 0
    fi

    local ceiling
    ceiling=$(grep -i "Trust Ceiling" "$ledger_path" | \
              awk -F'|' '{print $3}' | \
              tr -d ' ' | \
              grep -oE '^[0-4]')

    if [[ "$ceiling" =~ ^[0-4]$ ]]; then
        echo "$ceiling"
    else
        echo "4"  # Default to max if parse fails
    fi
}
```

**Why this works:**
- Trust ledger tables follow consistent format (established in Phase 8 templates)
- Grep isolates the row, awk splits on pipe delimiter, regex validates
- Graceful degradation to safe defaults (0 for current, 4 for ceiling)

### Pattern 2: Pre-Dispatch Trust Validation (Hierarchical Constraint)

**What:** Enforce parent trust ceiling before dispatching work to child workspace
**When to use:** Every cross-workspace dispatch, before health check and work routing
**Example:**
```bash
# Source: authority-boundary-ledger ring-based privilege hierarchy pattern
# Integrated into dispatch-to-workspace.sh after workspace resolution

validate_trust_ceiling() {
    local workspace_path="$1"
    local parent_ceiling="$2"  # From .worker/config.json

    local child_ledger="$workspace_path/.planning/trust-ledger.md"

    # Extract child's current trust level
    local child_level
    child_level=$(get_current_trust_level "$child_ledger")

    # Extract child's recorded ceiling
    local child_ceiling
    child_ceiling=$(get_trust_ceiling "$child_ledger")

    # Validation 1: Child ceiling must not exceed parent ceiling
    if [[ "$child_ceiling" -gt "$parent_ceiling" ]]; then
        echo "ERROR: Child workspace ceiling ($child_ceiling) exceeds parent ceiling ($parent_ceiling)" >&2
        echo "Child ledger is out of sync. Expected ceiling: $parent_ceiling" >&2
        return 1
    fi

    # Validation 2: Child current level must not exceed parent ceiling
    if [[ "$child_level" -gt "$parent_ceiling" ]]; then
        echo "ERROR: Child trust level ($child_level) exceeds parent ceiling ($parent_ceiling)" >&2
        echo "Child workspace has earned trust beyond parent's constraints." >&2

        # Generate improvement analysis (separate function)
        generate_improvement_analysis "$workspace_path" "$child_level" "$parent_ceiling"

        return 1
    fi

    # Validation 3: Ledger staleness check (event-driven)
    check_ledger_freshness "$workspace_path"

    return 0
}
```

**Key insight:** Fail fast before health check prevents wasted work. Child exceeding parent is a configuration error requiring immediate attention, not a recoverable health issue.

### Pattern 3: Child-to-Parent Improvement Analysis

**What:** When child outperforms parent, generate actionable analysis of differences
**When to use:** Trust ceiling violation detected in validate_trust_ceiling
**Example:**
```bash
# Source: Phase 11 user context (child outperformance feedback loop)
# Generates improvement task for parent workspace

generate_improvement_analysis() {
    local child_workspace="$1"
    local child_level="$2"
    local parent_ceiling="$3"

    local workspace_name
    workspace_name=$(basename "$child_workspace")

    echo "" >&2
    echo "=== IMPROVEMENT ANALYSIS ===" >&2
    echo "Child workspace '$workspace_name' has earned Level $child_level trust." >&2
    echo "Parent ceiling is Level $parent_ceiling." >&2
    echo "" >&2
    echo "This suggests child workspace has superior practices worth analyzing." >&2
    echo "" >&2

    # Compare workflows, skills, agents between parent and child
    local parent_root
    parent_root="$(cd "$SCRIPT_DIR/../.." && pwd)"

    # Generate diffs for key configuration areas
    echo "Analyzing configuration differences..." >&2

    # Compare trust guardrails
    if [[ -f "$child_workspace/.claude/trust-guardrails.yaml" ]] && \
       [[ -f "$parent_root/.claude/trust-guardrails.yaml" ]]; then
        echo "  - Trust guardrails differ" >&2
        diff -u "$parent_root/.claude/trust-guardrails.yaml" \
                "$child_workspace/.claude/trust-guardrails.yaml" \
                > /tmp/guardrails-diff.txt 2>/dev/null || true
    fi

    # Compare agent configurations
    local child_agent_count
    child_agent_count=$(find "$child_workspace/.claude/agents" -name "*.yaml" 2>/dev/null | wc -l)
    local parent_agent_count
    parent_agent_count=$(find "$parent_root/.claude/agents" -name "*.yaml" 2>/dev/null | wc -l)

    echo "  - Child has $child_agent_count agents vs parent $parent_agent_count" >&2

    # Compare skill count
    local child_skill_count
    child_skill_count=$(find "$child_workspace/.claude/skills" -name "*.md" 2>/dev/null | wc -l)
    local parent_skill_count
    parent_skill_count=$(find "$parent_root/.claude/skills" -name "*.md" 2>/dev/null | wc -l)

    echo "  - Child has $child_skill_count skills vs parent $parent_skill_count" >&2
    echo "" >&2

    # Create improvement task (GitHub issue)
    create_improvement_task "$workspace_name" "$child_level" "$parent_ceiling"
}

create_improvement_task() {
    local child_name="$1"
    local child_level="$2"
    local parent_ceiling="$3"

    # Check if gh CLI available
    if ! command -v gh &>/dev/null; then
        echo "Skipping GitHub issue creation (gh CLI not available)" >&2
        return 0
    fi

    local title="[Improvement] Analyze why $child_name outperformed parent"
    local body
    body=$(cat <<EOF
## Context

Child workspace \`$child_name\` has earned Level $child_level trust, exceeding parent ceiling of Level $parent_ceiling.

This indicates the child workspace has superior practices worth analyzing and potentially adopting at the parent level.

## Analysis Required

1. Compare trust guardrail configurations
2. Review agent definitions and constraints
3. Identify skill/workflow differences
4. Check session history patterns

## Actionable Diffs

\`\`\`bash
# Compare configurations
diff -u .claude/trust-guardrails.yaml projects/$child_name/.claude/trust-guardrails.yaml

# List agent differences
comm -3 <(ls -1 .claude/agents/*.yaml) <(ls -1 projects/$child_name/.claude/agents/*.yaml)
\`\`\`

## Recommendation

If child's practices are validated, consider:
- Adopting successful patterns at parent level
- Increasing parent ceiling to match demonstrated capability
- Documenting what enabled child's success

## Labels

\`enhancement\`, \`trust-system\`, \`pending-review\`
EOF
)

    # Create issue (non-blocking, best effort)
    gh issue create \
        --title "$title" \
        --body "$body" \
        --label "enhancement,trust-system,pending-review" \
        2>/dev/null || echo "Failed to create GitHub issue" >&2
}
```

**Unique insight:** Child outperformance isn't just a constraint violation—it's valuable feedback. The agency learns from its own workspaces.

### Pattern 4: Cross-Workspace Approval Workflow (Trust Level 3+)

**What:** Block high-trust cross-workspace operations and request explicit CEO approval
**When to use:** Cross-workspace dispatch where child or parent trust level >= 3
**Example:**
```bash
# Source: Adapted from approval-workflow.sh + manual-approval GitHub action patterns
# Integrated into dispatch-to-workspace.sh before execution

check_approval_requirement() {
    local workspace_id="$1"
    local task_description="$2"
    local trust_level="$3"  # Parent or child level (whichever is higher)

    # Trust level 3+ requires explicit approval for cross-workspace ops
    if [[ "$trust_level" -lt 3 ]]; then
        # No approval needed for lower trust levels
        return 0
    fi

    echo "Cross-workspace operation requires CEO approval (Trust Level $trust_level)" >&2

    # Create approval request using existing approval-workflow.sh
    source "$SCRIPT_DIR/../.claude/skills/ceo-dashboard/scripts/approval-workflow.sh"

    local context_json
    context_json=$(jq -nc \
        --arg workspace "$workspace_id" \
        --arg task "$task_description" \
        --arg level "$trust_level" \
        '{
            workspace: $workspace,
            task: $task,
            trust_level: ($level | tonumber),
            operation_type: "cross_workspace_dispatch"
        }')

    # Create approval request (returns approval_id)
    local approval_id
    approval_id=$(create_approval_request "cross_workspace" "orchestrator" "$context_json")

    if [[ -z "$approval_id" ]]; then
        echo "Failed to create approval request" >&2
        return 1
    fi

    echo "" >&2
    echo "Approval request created: $approval_id" >&2
    echo "Dispatched to CEO inbox for review." >&2
    echo "" >&2
    echo "To approve: Review issue and react with 👍" >&2
    echo "To deny: React with 👎" >&2
    echo "" >&2
    echo "Re-run this command after approval to continue." >&2

    # Exit and await approval (exit-and-resume pattern, not polling)
    return 1
}
```

**Key design:** Exit-and-resume (not polling) fits the GitHub coordination pattern. Work pauses, CEO reviews in inbox, approves/denies, then re-dispatches.

### Pattern 5: Ledger Staleness Detection (Event-Driven)

**What:** Detect when trust ledger hasn't been refreshed since last cross-workspace operation
**When to use:** Pre-dispatch validation, ensure trust state reflects recent activity
**Example:**
```bash
# Source: Phase 11 user context (event-driven staleness, not time-based)

check_ledger_freshness() {
    local workspace_path="$1"

    local ledger_path="$workspace_path/.planning/trust-ledger.md"
    local dispatch_log="$REPO_ROOT/.worker/dispatch/dispatch.jsonl"

    # Get last ledger update timestamp
    local ledger_mtime
    ledger_mtime=$(stat -c %Y "$ledger_path" 2>/dev/null || stat -f %m "$ledger_path" 2>/dev/null || echo "0")

    # Get last dispatch to this workspace
    local workspace_id
    workspace_id=$(basename "$workspace_path")

    local last_dispatch_time
    last_dispatch_time=$(grep "\"workspace_id\":\"$workspace_id\"" "$dispatch_log" 2>/dev/null | \
                         tail -1 | \
                         jq -r '.timestamp' 2>/dev/null | \
                         xargs -I{} date -d {} +%s 2>/dev/null || echo "0")

    # If dispatch happened after ledger update, ledger is stale
    if [[ "$last_dispatch_time" -gt "$ledger_mtime" ]]; then
        echo "WARNING: Trust ledger is stale (not updated since last dispatch)" >&2
        echo "Consider refreshing trust calculations before proceeding." >&2

        # Non-blocking warning, not a hard failure
        return 0
    fi

    return 0
}
```

**Why event-driven:** A ledger unchanged for 30 days might be fine if no work happened. A ledger unchanged since yesterday's dispatch is suspect.

### Anti-Patterns to Avoid

- **Polling for approvals**: Use exit-and-resume (GitHub coordination layer pattern)
- **Time-based staleness**: Use event-driven (last dispatch timestamp)
- **Full markdown parsing**: Use grep/awk for structured tables (reliable, no dependencies)
- **Runtime trust enforcement**: Validate at dispatch time (fail fast)
- **Ignoring child outperformance**: Generate improvement analysis (feedback loop)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown parsing | Custom markdown parser | grep/awk table extraction | Trust ledgers use regular table format; full parser overkill |
| Approval state machine | Custom polling loop | GitHub issue + exit-and-resume | Fits established GitHub coordination pattern |
| Trust ledger format validation | Complex regex engine | Basic header checks + safe defaults | Over-validation is brittle; graceful degradation better |
| Cross-workspace diff generation | Custom diff algorithm | GNU diff with -u flag | Unified diff format is readable and standard |

**Key insight:** Trust ledgers are markdown but highly structured. Table extraction via awk is more reliable than full markdown parsing libraries.

## Common Pitfalls

### Pitfall 1: Trust Ledger Parse Failures Create Trust Holes

**What goes wrong:** If ledger parsing fails silently, defaults might grant unintended trust
**Why it happens:** Graceful degradation defaults to permissive values (ceiling=4, level=0)
**How to avoid:**
- Default current level to 0 (most restrictive for child)
- Default ceiling to parent's ceiling (not 4) when validating child
- Log parse failures to audit trail
- Validate ledger format during workspace health check

**Warning signs:**
- Child workspace unexpectedly allowed to proceed
- Missing "Trust Ceiling" or "Current Level" headers
- Ledger file exists but is empty

### Pitfall 2: Race Condition Between Dispatch and Ledger Update

**What goes wrong:** Ledger updated between validation and execution, trust level changes
**Why it happens:** Multi-step process with file-based state
**How to avoid:**
- Read ledger once, store values in variables
- Don't re-parse during execution
- Log parsed values to audit trail for forensics
- Accept that trust might change between dispatches (human updates ledger)

**Warning signs:**
- Audit trail shows different trust level than dispatch used
- Dispatch succeeds but ledger shows different constraints

### Pitfall 3: Circular Improvement Tasks When Child Always Leads

**What goes wrong:** Every dispatch creates GitHub issue, inbox floods
**Why it happens:** Child maintains higher trust than parent, triggers on every dispatch
**How to avoid:**
- Check if improvement task already exists before creating
- Use GitHub issue search: `gh issue list --label "trust-system" --search "workspace-name"`
- Only create task on FIRST detection of ceiling violation
- Record task creation in dispatch log to prevent duplicates

**Warning signs:**
- Multiple identical improvement tasks in GitHub
- Inbox flooded with same analysis repeatedly

### Pitfall 4: Approval Timeout Confusion

**What goes wrong:** User expects auto-timeout like approval-workflow.sh, but cross-workspace has none
**Why it happens:** Exit-and-resume pattern vs. polling pattern
**How to avoid:**
- Document clearly: approvals don't auto-deny after 24 hours
- Approval request is durable (lives in .worker/approvals/pending/)
- Separate cleanup process can expire old approvals
- CEO must explicitly approve or deny (or ignore indefinitely)

**Warning signs:**
- Old approval requests still pending after days
- User confusion about "when will this auto-deny"

### Pitfall 5: Stale Ledger False Positives

**What goes wrong:** Ledger flagged as stale even though it's current
**Why it happens:** File mtime vs. dispatch timestamp comparison edge cases
**How to avoid:**
- Make staleness a WARNING not ERROR
- Allow dispatch to proceed even if stale
- Document that staleness is a signal, not a blocker
- Consider ledger "Last Updated" field as source of truth (not file mtime)

**Warning signs:**
- Ledger clearly updated but flagged as stale
- Dispatch blocked unnecessarily

## Code Examples

Verified patterns from architecture section above.

### Extract Trust Level from Ledger

```bash
# Source: Pattern 1 above
get_current_trust_level() {
    local ledger_path="$1"

    if [[ ! -f "$ledger_path" ]]; then
        echo "0"
        return 0
    fi

    local level
    level=$(grep -i "Current Level" "$ledger_path" | \
            awk -F'|' '{print $3}' | \
            tr -d ' ' | \
            grep -oE '^[0-4]')

    if [[ "$level" =~ ^[0-4]$ ]]; then
        echo "$level"
    else
        echo "0"
    fi
}
```

### Validate Trust Ceiling Before Dispatch

```bash
# Source: Pattern 2 above
validate_trust_ceiling() {
    local workspace_path="$1"
    local parent_ceiling="$2"

    local child_ledger="$workspace_path/.planning/trust-ledger.md"
    local child_level=$(get_current_trust_level "$child_ledger")
    local child_ceiling=$(get_trust_ceiling "$child_ledger")

    if [[ "$child_ceiling" -gt "$parent_ceiling" ]]; then
        echo "ERROR: Child ceiling ($child_ceiling) > parent ($parent_ceiling)" >&2
        return 1
    fi

    if [[ "$child_level" -gt "$parent_ceiling" ]]; then
        echo "ERROR: Child level ($child_level) > parent ceiling ($parent_ceiling)" >&2
        generate_improvement_analysis "$workspace_path" "$child_level" "$parent_ceiling"
        return 1
    fi

    check_ledger_freshness "$workspace_path"
    return 0
}
```

### Request Cross-Workspace Approval

```bash
# Source: Pattern 4 above
check_approval_requirement() {
    local workspace_id="$1"
    local task_description="$2"
    local trust_level="$3"

    if [[ "$trust_level" -lt 3 ]]; then
        return 0  # No approval needed
    fi

    source "$SCRIPT_DIR/../.claude/skills/ceo-dashboard/scripts/approval-workflow.sh"

    local context_json=$(jq -nc \
        --arg workspace "$workspace_id" \
        --arg task "$task_description" \
        --arg level "$trust_level" \
        '{workspace: $workspace, task: $task, trust_level: ($level | tonumber)}')

    local approval_id=$(create_approval_request "cross_workspace" "orchestrator" "$context_json")

    echo "Approval request: $approval_id" >&2
    echo "Re-run after CEO approval." >&2

    return 1  # Block dispatch until approval
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Runtime permission checks | Pre-dispatch validation | Phase 11 (2026-01) | Fail fast prevents wasted work |
| Time-based ledger expiry | Event-driven staleness | Phase 11 (2026-01) | Matches actual usage patterns |
| Polling for approvals | Exit-and-resume | Phase 7 (2026-01) | Cleaner shell exits, fits GitHub pattern |
| Markdown parsing libraries | grep/awk table extraction | Phase 8 (2026-01) | No dependencies, more reliable for structured tables |

**Deprecated/outdated:**
- Polling-based approval workflows (use exit-and-resume instead)
- Time-based trust ledger staleness (use event-driven instead)
- Complex markdown parsing for trust ledgers (use awk table extraction)

## Open Questions

1. **How to handle parent trust level changes?**
   - What we know: Parent ceiling is in .worker/config.json (guardrails.default_trust_level)
   - What's unclear: Should child ledgers auto-update when parent changes, or require manual sync?
   - Recommendation: Require manual sync (validate child <= parent on every dispatch, flag mismatches)

2. **Should improvement tasks be auto-assigned?**
   - What we know: User context says "pending acceptance, not auto-assigned"
   - What's unclear: Who reviews and decides whether to adopt child practices?
   - Recommendation: Create unassigned, CEO triages in inbox (fits inbox-driven workflow)

3. **Can cross-workspace operations chain approvals?**
   - What we know: Each workspace dispatch requires approval if trust >= 3
   - What's unclear: If Workspace A dispatches to Workspace B which dispatches to C, how many approvals?
   - Recommendation: One approval per dispatch (CEO sees full chain in audit trail)

## Sources

### Primary (HIGH confidence)

- [authority-boundary-ledger](https://rosetta-labs-erb.github.io/authority-boundary-ledger/) - Ring-based hierarchical trust constraints, defensive justifiability model
- [manual-approval GitHub Action](https://github.com/trstringer/manual-approval) - Issue-based approval workflow, exit-and-resume pattern
- Phase 8 RESEARCH.md - Trust ledger format, markdown table extraction patterns
- docs/GUARDRAILS.md - Existing trust system architecture, hook integration points
- .claude/skills/worker/lib/hooks.sh - Pre/post hook execution patterns (verified code)
- .claude/skills/ceo-dashboard/scripts/approval-workflow.sh - Approval state machine (verified code)

### Secondary (MEDIUM confidence)

- [Claude Code Hooks](https://www.datacamp.com/tutorial/claude-code-hooks) - PreToolUse event patterns for validation
- [Vercel bash-tool](https://www.infoq.com/news/2026/01/vercel-bash-tool/) - Bash execution engine for AI agents
- [GitHub Actions workflow approvals](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks) - Approval workflow patterns

### Tertiary (LOW confidence)

- Various bash/jq parsing tutorials - General patterns for JSON/markdown manipulation
- GitHub community discussions on approval prompts - User experience insights

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools proven in Phases 8-10
- Architecture patterns: HIGH - Builds on validated Phase 8 workspace patterns
- Trust ceiling enforcement: HIGH - authority-boundary-ledger provides proven hierarchical model
- Approval workflows: HIGH - approval-workflow.sh already implemented and tested
- Child improvement analysis: MEDIUM - Novel pattern, requires validation
- Pitfalls: MEDIUM - Based on general bash scripting experience, not all specific to this domain

**Research date:** 2026-01-30
**Valid until:** 60 days (stable domain - bash scripting, git, GitHub patterns are mature)

# Phase 12: Anti-Gravity Integration - Research

**Researched:** 2026-01-31
**Domain:** Google Antigravity Agent Manager integration, Gemini orchestration, hybrid agents.md + skills architecture
**Confidence:** HIGH

## Summary

Phase 12 integrates the existing CLI-based orchestration system (dispatch.sh, execute.sh, workspace scripts) with Google Antigravity Agent Manager as the primary CEO interface. The technical foundation is complete—this phase wires Gemini to invoke it through the Agent Manager UI.

**Critical insight from Vercel research:** AGENTS.md outperformed skills by 47 percentage points (100% vs 53% pass rate) due to a fundamental problem: **in 56% of eval cases, skills were never invoked**. This directly validates the CONTEXT.md decision to use a hybrid approach: core orchestration behavior lives in agents.md (always loaded), while explicit CEO commands remain as skills (user-triggered).

**Primary recommendation:** Implement a hybrid architecture with core orchestration logic in `.gemini/agents.md` for zero-decision overhead, and explicit commands as `.gemini/skills/` for user-triggered workflows like `/status`, `/briefing`, `/approve N`.

## Standard Stack

### Core
| Library/Tool | Version/Type | Purpose | Why Standard |
|--------------|--------------|---------|--------------|
| Google Antigravity | 2026 release | Agent Manager IDE | Google's official agentic development platform with Gemini integration |
| Gemini 3 Pro/Flash | Latest | Primary orchestrator model | Native integration, supports context caching, function calling |
| AGENTS.md | Open standard | Core orchestration context | Vercel research shows 100% pass rate vs 53% for skills |
| SKILL.md | Agent Skills spec | User-triggered commands | Supported by 25+ platforms, portable across ecosystem |
| run_shell_command | Built-in tool | Terminal execution | Native Gemini CLI capability for bash/powershell |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Context caching | Gemini API | Reduce token costs | Cache agents.md content (60min default TTL) |
| Progressive disclosure | SKILL.md pattern | Lazy-load skill details | Only load full skill when description matches intent |
| JSONL event logs | Custom | Audit trail, frecency tracking | Workspace access patterns, approval records |
| Markdown frontmatter | YAML | Skill metadata | Name + description for semantic matching |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hybrid approach | Skills-only | 56% skill non-invocation rate makes this unreliable |
| Gemini in Agent Manager | Gemini CLI only | Loses inbox view, artifacts panel, workspace sidebar |
| AGENTS.md | Individual files | No single source of truth for orchestration behavior |

**Installation:**
```bash
# No new dependencies - uses existing Antigravity installation
# Skills go in: ~/.gemini/antigravity/skills/ (global) or .gemini/skills/ (project)
# Agents.md goes in: .gemini/agents.md
```

## Architecture Patterns

### Recommended Project Structure
```
.gemini/
├── agents.md              # Core orchestration (always loaded)
│   ├── Intent classification
│   ├── Workspace awareness
│   ├── Trust/guardrails summary
│   └── Script location index
├── skills/
│   ├── status/
│   │   └── SKILL.md       # /status command
│   ├── briefing/
│   │   └── SKILL.md       # /briefing command
│   ├── approve/
│   │   └── SKILL.md       # /approve N command
│   └── dispatch/
│       └── SKILL.md       # /dispatch "intent" command
```

### Pattern 1: Hybrid Context Loading (Core Architecture)

**What:** Core orchestration behavior in agents.md, explicit commands as skills

**When to use:** When you need reliable passive context (always available) plus user-triggered workflows

**Rationale from Vercel research:**
- AGENTS.md: No decision overhead, persistent availability, 100% pass rate
- Skills: Better for vertical, user-triggered workflows (no passive invocation needed)

**Example:**
```markdown
<!-- .gemini/agents.md -->
# Manifest Automations Orchestrator

You are the orchestration layer between CEO intent and Claude worker execution.

## Intent Classification

Classify CEO input before acting:
- DISPATCH: Action words (build, implement, create, fix) → Decompose and dispatch
- STATUS: Query words (status, progress, what's) → Aggregate and report
- DECISION: References to blocked items → Present options
- CORRECTION: Stop words (stop, pause, cancel) → Halt workflow
- CONVERSATION: None of above → Ask clarifying questions

## Workspace Awareness

Current workspace shown in sidebar. For cross-workspace requests:
1. Resolve via: scripts/workspace/workspace-resolve.sh "<name>"
2. Check health: scripts/workspace/workspace-health.sh "<path>"
3. Validate trust: scripts/trust/validate-ceiling.sh "<workspace>"
4. Request approval if cross-workspace (Phase 11)

## Script Index

For retrieval when needed (do NOT include full content here):
- Dispatch: scripts/orchestrator/dispatch.sh
- Status: scripts/orchestrator/aggregate.sh
- Graph: scripts/orchestrator/graph.sh
- Execute: scripts/worker/execute.sh
```

**Source:** [Vercel blog - AGENTS.md outperforms skills](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)

### Pattern 2: Progressive Disclosure for Skills

**What:** Skills use YAML frontmatter for lightweight metadata; full body loaded only when invoked

**When to use:** For explicit commands where invocation is deterministic (user types `/status`)

**Example:**
```markdown
<!-- .gemini/skills/status/SKILL.md -->
---
name: status
description: Show orchestration dashboard with worker status and aggregate metrics
---

# Status Skill

When user requests status (via "/status" or "show status"):

1. Run status aggregation:
   ```bash
   scripts/orchestrator/aggregate.sh --format table --scope active
   ```

2. Parse output and present in conversation with icons:
   - [..] = executing
   - [??] = awaiting approval
   - [OK] = complete
   - [XX] = failed
   - [--] = partial

3. Surface actionable items:
   - Approval requests: "Issue #N needs review"
   - Failures: "Issue #N failed: [error context]"
   - Blockers: "Issue #N blocked by #M"
```

**Source:** [Google Codelabs - Authoring Antigravity Skills](https://codelabs.developers.google.com/getting-started-with-antigravity-skills)

### Pattern 3: Inbox Parsing and Surfacing

**What:** Read `.worker/inbox/*.md` files and surface pending items in conversation

**When to use:**
- On conversation start (proactive check)
- On explicit request ("check inbox", "status")
- Do NOT poll between turns (too noisy)

**Example:**
```markdown
<!-- In agents.md -->
## Inbox Checking

On conversation start or when CEO asks for status:
1. List inbox files: ls .worker/inbox/*.md (exclude .queued)
2. Parse frontmatter for metadata (type, tier, timestamp)
3. Surface in priority order: immediate > urgent > normal
4. Group by type: approval, violation, briefing, message

Format for CEO:
```
Inbox (3 pending):

[CRITICAL] Approval Required (#1769712022771213800)
- Type: critical_violation
- Agent: test-agent
- Actions: [Approve](action://approve?id=...)

[Briefing] Daily briefing ready (#1769712716813896000)
...
```
```

**Source:** Existing `.worker/inbox/` format from codebase

### Pattern 4: Terminal Execution with Error Handling

**What:** Use `run_shell_command` tool with proper error checking and retry logic

**When to use:** Any bash script invocation from Gemini

**Example:**
```markdown
<!-- In skill or agents.md instruction -->
To dispatch worker:

1. Call run_shell_command:
   - command: "scripts/orchestrator/dispatch.sh --issue 42"
   - description: "Dispatch Claude worker for issue #42"
   - directory: "." (relative to project root)

2. Check execution result:
   - Exit Code 0: Success, parse stdout for PID
   - Exit Code 1: Transient failure (lock timeout) → Retry with --force
   - Exit Code 2: Persistent failure → Escalate to CEO with context

3. Auto-retry conditions (transient failures only):
   - Lock timeout: retry with --force flag
   - Parse errors: retry after template fix
   - Rate limit: retry after backoff

4. Escalate to CEO (persistent failures):
   - Execution failures
   - Validation failures
   - Permission errors
   - Multiple consecutive failures
```

**Security note:** `run_shell_command` restrictions are "not a security mechanism" (can be easily bypassed). Trust is enforced at the script level, not the invocation level.

**Source:** [Gemini CLI - Shell Tool](https://geminicli.com/docs/tools/shell/)

### Pattern 5: Artifacts Panel for Confirmation Gates

**What:** Show plan in Artifacts panel before dispatching to Claude workers

**When to use:** CEO approval gate before creating GitHub issues or dispatching workers

**Example flow:**
```
CEO: "Build dark mode for the dashboard"

Gemini (in Artifacts panel):
┌─────────────────────────────────────┐
│ Decomposition Plan                  │
│                                     │
│ Issue 1: Foundation - Theme system  │
│ - Size: M (2-4h)                    │
│ - Dependencies: None                │
│ - Acceptance:                       │
│   • CSS variables defined           │
│   • Toggle component works          │
│   • Choice persists in localStorage │
│                                     │
│ Issue 2: Dark mode for dashboard    │
│ - Size: S (1-2h)                    │
│ - Blocked by: #1                    │
│ ...                                 │
└─────────────────────────────────────┘

Gemini (in conversation):
"Ready to create these issues and dispatch #1?"

CEO: "yes"

Gemini:
[Creating issues via gh CLI...]
[Dispatching worker for #1...]
```

**Note:** Antigravity Agent Manager doesn't have a dedicated "artifacts panel" like Claude's interface, but Gemini can use structured previews in the conversation before execution via the confirmation prompt pattern built into `run_shell_command`.

**Source:** [Gemini CLI configuration docs](https://geminicli.com/docs/get-started/configuration/) - default safe mode with [Y/n] prompts

### Pattern 6: Workspace Context Persistence

**What:** Conversation scoped to workspace (visible in sidebar), context persists across messages

**When to use:** Multi-turn CEO conversations within a single project

**Agent Manager behavior:**
- Workspace shown in sidebar: "Manifest Automations / go to antigravity.google"
- Conversation title auto-generated from initial intent
- Context persists within conversation (no need to re-establish workspace)
- New conversation = new context (explicitly switch workspace if needed)

**Cross-workspace dispatch:**
```markdown
CEO: "Deploy the login feature in Project X"

Gemini:
1. Resolve "Project X" → scripts/workspace/workspace-resolve.sh "Project X"
2. Check health → scripts/workspace/workspace-health.sh "<resolved-path>"
3. Validate trust → scripts/trust/validate-ceiling.sh "Project X"
4. Request approval → "Cross-workspace dispatch requires approval. Proceed? [Y/n]"
5. If approved → dispatch via Project X workspace scripts
```

**Source:** [Google ADK - Context scoping patterns](https://developers.googleblog.com/architecting-efficient-context-aware-multi-agent-framework-for-production/)

### Anti-Patterns to Avoid

- **Polling inbox between turns:** Too noisy. Check proactively on conversation start and on explicit request only.
- **Putting full script content in agents.md:** Use index pattern instead. Include location for retrieval, not full code.
- **Relying on skill invocation for passive context:** Vercel research shows 56% non-invocation rate. Use agents.md for always-available context.
- **Manual script logic in skills:** Delegate to bash scripts. Skills should orchestrate, not implement.
- **Unbounded context in agents.md:** Keep concise. Use retrieval reasoning over pre-training reasoning (fetch scripts when needed).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Intent classification | Custom NLP logic | Simple pattern matching in agents.md | Gemini already excels at intent classification from natural language |
| Workspace resolution | Manual path construction | `workspace-resolve.sh` with frecency | Already handles exact match, submodules, aliases, frecency scoring |
| Dependency graphs | Custom graph algorithms | `graph.sh` topological sort | Already validates cycles, provides execution order, cascade detection |
| Terminal execution | Custom subprocess wrappers | `run_shell_command` built-in tool | Native Gemini CLI capability with error handling, exit codes, streams |
| Context caching | Manual token management | Gemini's implicit caching | Automatic 24hr TTL, 90% cost reduction on cached tokens |
| Skill loading | Custom file parsing | Progressive disclosure pattern | Agent only loads YAML frontmatter initially, full body on invocation |

**Key insight:** The execution machinery is complete (Phase 5-11). Phase 12 is a thin adapter layer connecting Gemini in Agent Manager to existing bash scripts.

## Common Pitfalls

### Pitfall 1: Skill Non-Invocation

**What goes wrong:** Skills defined but never invoked by agent, resulting in zero improvement over baseline

**Why it happens:** Agent must decide when to invoke skill based on description match. Vague descriptions or wrong context placement leads to missed invocations.

**How to avoid:**
- Use hybrid approach: core behavior in agents.md (always loaded)
- Skills only for explicit user commands (`/status`, `/approve N`)
- Precise skill descriptions: "Executes read-only SQL queries against local PostgreSQL" not "Database tools"

**Warning signs:**
- Skill exists but agent never mentions it
- User has to explicitly say "use the X skill"
- Metrics show low skill invocation rate

**Source:** [Vercel blog - 56% skill non-invocation rate](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)

### Pitfall 2: Context Explosion in Agents.md

**What goes wrong:** Putting full script content in agents.md bloats context, wastes tokens, confuses model

**Why it happens:** Trying to make everything "always available" instead of using retrieval patterns

**How to avoid:**
- **Index pattern:** List script locations, not full content
- **Retrieval reasoning:** Fetch script content when needed via `cat scripts/...`
- **Aggressive compression:** Remove comments, collapse whitespace for essential content
- **Progressive disclosure:** Skills load full body only when invoked

**Warning signs:**
- agents.md file is >5KB
- Context cache costs are high
- Model responses reference outdated logic

**Source:** [Vercel blog - 80% size reduction maintains 100% pass rate](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)

### Pitfall 3: Unsafe Retry Logic

**What goes wrong:** Retrying non-idempotent operations (file writes, issue creation) causes duplicates or corruption

**Why it happens:** Treating all failures as transient without checking operation idempotency

**How to avoid:**
- **Only auto-retry transient failures:** Lock timeout, rate limits, network errors
- **Escalate persistent failures:** Validation errors, permission errors, multiple consecutive failures
- **Check idempotency:** Is retry safe? (Status check: yes, Issue creation: no)
- **Use exit codes:** 0 = success, 1 = transient (retry), 2 = persistent (escalate)

**Warning signs:**
- Duplicate GitHub issues created
- File corruption from partial retries
- Cascading failures from retry loops

**Source:** [Building Resilient Multi-Agent Systems with Google ADK](https://medium.com/@sarojkumar.rout/building-resilient-multi-agent-systems-with-google-adk-a-practical-guide-to-timeout-retry-and-1b98a594fa1a)

### Pitfall 4: Cross-Workspace Context Leakage

**What goes wrong:** Agent uses workspace A context when operating on workspace B, causing wrong file paths or logic

**Why it happens:** Conversation context persists, workspace switching not explicit

**How to avoid:**
- **Explicit resolution:** Always call `workspace-resolve.sh` for cross-workspace requests
- **Validation gate:** Show resolved workspace to CEO before dispatching
- **Scoped conversations:** Workspace visible in sidebar, new conversation for new workspace
- **Approval required:** Phase 11 approval gate for cross-workspace dispatch

**Warning signs:**
- Dispatch targets wrong workspace
- File operations fail with "path not found"
- Trust violations from unexpected workspace access

**Source:** [Google ADK - Context scoping](https://developers.googleblog.com/architecting-efficient-context-aware-multi-agent-framework-for-production/)

### Pitfall 5: Inbox Polling Noise

**What goes wrong:** Checking inbox on every turn creates noisy, distracting experience

**Why it happens:** Trying to be "proactive" without considering conversation flow

**How to avoid:**
- **Check on conversation start:** First turn only (proactive)
- **Check on explicit request:** "status", "check inbox", etc.
- **Do NOT poll between turns:** Stay silent when no state changes
- **Aggregate before surfacing:** Group by priority, type before presenting

**Warning signs:**
- Every response starts with "Inbox status..."
- CEO complains about noise
- Important items buried in repetitive updates

**Source:** Best practice from existing orchestrator skill + Agent Manager UX patterns

## Code Examples

Verified patterns from official sources and existing codebase:

### Intent Classification in Agents.md

```markdown
<!-- .gemini/agents.md -->
## Intent Classification

Before acting, classify CEO input by pattern matching:

**DISPATCH patterns:**
- Action verbs: build, implement, create, add, fix, update, deploy, ship, make, configure
- Example: "Build the login page" → DISPATCH
- Action: Decompose into issues, dispatch workers

**STATUS patterns:**
- Query words: status, progress, what's, how's, show, list, report, where, which
- Example: "What's the status?" → STATUS
- Action: Run aggregate.sh, present table

**DECISION patterns:**
- Decision keywords: blocked, waiting, decide, approve, review, choose, pick, select
- Example: "The blocked items need attention" → DECISION
- Action: Present options for blocked issues

**CORRECTION patterns:**
- Stop words: stop, pause, cancel, abort, halt, hold, delay, postpone
- Example: "Stop that work" → CORRECTION
- Action: Kill worker process, update labels

**CONVERSATION patterns:**
- None of above patterns match
- Example: "Tell me about the project" → CONVERSATION
- Action: Ask clarifying questions
```

**Source:** `.gemini/skills/orchestrate.md` from codebase

### Skill Definition with Progressive Disclosure

```markdown
<!-- .gemini/skills/status/SKILL.md -->
---
name: status
description: Show orchestration dashboard with active worker status and aggregate metrics
---

# Status Dashboard Skill

## Goal
Provide CEO with current state of all active workers and pending items.

## Instructions

1. **Determine scope:**
   - Default: active workers (worker:* labels)
   - If CEO says "all": include closed issues
   - If CEO says "phase N": filter to phase

2. **Run aggregation:**
   ```bash
   run_shell_command(
     command: "scripts/orchestrator/aggregate.sh --format table --scope active",
     description: "Aggregate worker status for dashboard",
     directory: "."
   )
   ```

3. **Check exit code:**
   - 0: Parse stdout, present table
   - 1: Report error, suggest retry
   - 2: Escalate to CEO

4. **Present with context:**
   ```
   Status | Issue  | Title                        | Updated
   -------|--------|------------------------------|--------
   [..]   | #52    | Foundation - Theme system    | 2m ago
   [??]   | #53    | Dark mode for dashboard      | 5m ago
   [XX]   | #54    | Dark mode for settings       | 8m ago
   ```

5. **Surface actionable items:**
   - [??] = "Issue #N awaiting approval. Review plan?"
   - [XX] = "Issue #N failed. Options: retry, modify, abandon"
   - Blocked = "Issue #N blocked by #M"

## Constraints
- Never modify GitHub state (read-only)
- Always show issue numbers for reference
- Group by status for clarity
```

**Source:** [Google Codelabs - Antigravity Skills](https://codelabs.developers.google.com/getting-started-with-antigravity-skills)

### Terminal Execution with Error Handling

```typescript
// Pattern for run_shell_command invocation from Gemini

// 1. Execute with parameters
const result = await run_shell_command({
  command: "scripts/orchestrator/dispatch.sh --issue 42",
  description: "Dispatch Claude worker for issue #42",
  directory: "."
});

// 2. Check exit code
if (result.exitCode === 0) {
  // Success: Parse stdout for PID
  const pid = result.stdout.match(/Worker PID: (\d+)/)?.[1];
  return `Dispatched worker for #42 (PID: ${pid})`;

} else if (result.exitCode === 1) {
  // Transient failure: Check if lock timeout
  if (result.stderr.includes("Lock held by another process")) {
    // Auto-retry with force flag
    const retryResult = await run_shell_command({
      command: "scripts/orchestrator/dispatch.sh --issue 42 --force",
      description: "Retry dispatch with force flag",
      directory: "."
    });
    return handleResult(retryResult);
  }
  // Other transient: Report to CEO
  return `Dispatch failed (transient): ${result.stderr}. Retry? [Y/n]`;

} else if (result.exitCode === 2) {
  // Persistent failure: Escalate with context
  return `Dispatch failed (persistent): ${result.stderr}\n\nOptions:\n1. Modify issue scope\n2. Check dependencies\n3. Abandon`;
}
```

**Source:** [Gemini CLI - Shell Tool documentation](https://geminicli.com/docs/tools/shell/)

### Inbox Parsing and Prioritization

```bash
# In agents.md or skill, pattern for inbox checking

# 1. List active inbox files (exclude .queued suffix)
INBOX_FILES=$(ls .worker/inbox/*.md 2>/dev/null | grep -v '\.queued$')

# 2. For each file, parse frontmatter
for file in $INBOX_FILES; do
  # Extract YAML frontmatter
  TYPE=$(grep '^type:' "$file" | head -1 | cut -d' ' -f2)
  TIMESTAMP=$(grep '^timestamp:' "$file" | head -1 | cut -d' ' -f2)
  TIER=$(grep '^tier:' "$file" | head -1 | cut -d' ' -f2)

  # Categorize by tier
  case "$TIER" in
    immediate) PRIORITY=1 ;;
    urgent)    PRIORITY=2 ;;
    normal)    PRIORITY=3 ;;
    *)         PRIORITY=4 ;;
  esac

  # Store for sorting
  echo "$PRIORITY|$TIMESTAMP|$TYPE|$file"
done | sort -t'|' -k1,1n -k2,2r  # Sort by priority, then timestamp desc

# 3. Surface in conversation grouped by type
```

**Example output:**
```
Inbox (3 pending):

[CRITICAL] Approval Required
- Type: critical_violation
- Agent: test-agent
- Request ID: approval-1769712021924961400
- Actions: [Approve](action://approve?id=...) [Deny](action://deny?id=...)

[Briefing] Daily briefing ready
- Timestamp: 2026-01-29T18:45:16Z
- File: 1769712716813896000-briefing.md

[Message] Cross-workspace request
- From: high-trust-workspace
- Timestamp: 2026-01-30T06:51:31Z
```

**Source:** Existing `.worker/inbox/` format from codebase

### Frecency-Based Workspace Resolution

```bash
# In agents.md, pattern for cross-workspace requests

# CEO says: "Deploy the login feature in Project X"

# 1. Resolve workspace name to path
WORKSPACE_PATH=$(scripts/workspace/workspace-resolve.sh "Project X")
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  # Resolved successfully
  echo "Resolved 'Project X' to: $WORKSPACE_PATH"

  # 2. Check workspace health
  HEALTH=$(scripts/workspace/workspace-health.sh "$WORKSPACE_PATH")
  if [ $? -ne 0 ]; then
    echo "Warning: Workspace health check failed: $HEALTH"
    echo "Proceed anyway? [Y/n]"
    # Await CEO decision
  fi

  # 3. Validate trust ceiling (Phase 11)
  scripts/trust/validate-ceiling.sh "$WORKSPACE_PATH"
  if [ $? -ne 0 ]; then
    echo "Trust validation failed. Cross-workspace dispatch requires approval."
    # Request approval gate
  fi

  # 4. Record frecency event
  scripts/workspace/workspace-frecency.sh record "Project X"

  # 5. Dispatch in workspace context
  cd "$WORKSPACE_PATH"
  scripts/orchestrator/dispatch.sh --issue N

else
  # Resolution failed
  echo "Could not resolve 'Project X'. Available workspaces:"
  scripts/workspace/workspace-list.sh
  echo "Did you mean one of these?"
fi
```

**Source:** `scripts/workspace/workspace-resolve.sh` and `workspace-frecency.sh` from codebase

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Skills-only | Hybrid (agents.md + skills) | 2025-11 | Vercel research: 47pp improvement (100% vs 53%) |
| Manual caching | Implicit caching | Gemini 2.5+ | 90% token cost reduction, 24hr default TTL |
| Separate .claude/ and .gemini/ | Unified .agent/skills/ | 2026 Agent Skills spec | 25+ platforms support, cross-tool portability |
| Bounded context in prompts | Retrieval reasoning | 2025-2026 | Fetch scripts on-demand vs. bloating agents.md |
| Sequential skill loading | Progressive disclosure | 2026 | Load YAML frontmatter only, full body on invocation |

**Deprecated/outdated:**
- **Skills-only architecture:** 56% non-invocation rate makes unreliable for passive context
- **Pre-v2.5 explicit caching:** Implicit caching now default, simpler configuration
- **Polling-based inbox:** Too noisy; check proactively on start and on request only
- **Global-only skills:** Agent Skills spec supports both global (~/.gemini/antigravity/skills/) and project (.gemini/skills/)

## Open Questions

1. **Artifacts panel equivalent in Agent Manager**
   - What we know: Agent Manager doesn't have dedicated "artifacts panel" like Claude Code
   - What's unclear: Best UI pattern for showing decomposition before execution
   - Recommendation: Use structured preview in conversation + confirmation prompt (native to `run_shell_command`)

2. **Push notifications on worker completion**
   - What we know: Deferred per CONTEXT.md (requires Agent Manager capability)
   - What's unclear: If/when Agent Manager will support background task notifications
   - Recommendation: Defer to future phase, use proactive inbox checking on conversation start

3. **"Prefer retrieval reasoning over pre-training reasoning" instruction**
   - What we know: Mentioned in CONTEXT.md as research finding for agents.md
   - What's unclear: Exact phrasing, whether it's official Gemini guidance or community pattern
   - Recommendation: Use pattern "For script details, fetch via `cat scripts/...` rather than including full content here" in agents.md

4. **Conversation-scoped workspace vs. multi-workspace sessions**
   - What we know: Agent Manager shows workspace in sidebar, conversation is scoped
   - What's unclear: How to switch workspace mid-conversation vs. starting new conversation
   - Recommendation: New conversation per workspace (cleaner context), cross-workspace dispatch via explicit resolution

## Sources

### Primary (HIGH confidence)
- [Vercel - AGENTS.md outperforms skills in agent evals](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals) - 56% skill non-invocation rate, 47pp improvement
- [Google Codelabs - Authoring Antigravity Skills](https://codelabs.developers.google.com/getting-started-with-antigravity-skills) - Skill structure, progressive disclosure
- [Gemini CLI - Shell Tool documentation](https://geminicli.com/docs/tools/shell/) - run_shell_command parameters, error handling
- [Google Cloud - Context caching overview](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/context-cache/context-cache-overview) - TTL defaults, cost optimization
- Existing codebase: `scripts/orchestrator/`, `scripts/workspace/`, `.worker/inbox/` format

### Secondary (MEDIUM confidence)
- [Medium - Building Resilient Multi-Agent Systems with Google ADK](https://medium.com/@sarojkumar.rout/building-resilient-multi-agent-systems-with-google-adk-a-practical-guide-to-timeout-retry-and-1b98a594fa1a) - Retry patterns, fallback strategies
- [Google Developers Blog - Architecting efficient context-aware multi-agent framework](https://developers.googleblog.com/architecting-efficient-context-aware-multi-agent-framework-for-production/) - Context scoping, workspace isolation
- [Agents Arcade - Error Handling in Agentic Systems](https://agentsarcade.com/blog/error-handling-agentic-systems-retries-rollbacks-graceful-failure) - Idempotency considerations
- [AGENTS.md official site](https://agents.md/) - Standard format reference

### Tertiary (LOW confidence)
- [Medium - Skills.md vs. Agent Tools](https://medium.com/data-science-collective/skills-md-vs-agent-tools-are-we-reinventing-the-wheel-1eb0308110a2) - Comparison discussion
- Community discussions on Agent Skills adoption across 25+ platforms

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified via official Google docs, Vercel research, codebase inspection
- Architecture: HIGH - Hybrid pattern validated by Vercel research (100% pass rate), existing scripts confirm execution layer complete
- Pitfalls: HIGH - Vercel 56% non-invocation finding, error handling patterns from Google ADK docs
- Agent Manager specifics: MEDIUM - Screenshots confirm inbox view, workspace sidebar; artifacts panel pattern inferred from Gemini CLI confirmation prompts

**Research date:** 2026-01-31
**Valid until:** 2026-03-15 (45 days - stable ecosystem, but Agent Manager evolving rapidly)

**Key validation needed during planning:**
- Confirm exact agents.md section organization with user (Claude's discretion per CONTEXT.md)
- Test skill invocation patterns in Agent Manager (ensure `/status` triggers correctly)
- Verify inbox file parsing handles all message types from Phase 10-11
- Validate cross-workspace approval gate integration (Phase 11)

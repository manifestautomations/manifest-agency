# Phase 12: Anti-Gravity Integration - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Adapt existing CLI-based orchestration, dashboard, briefing, and approval systems to work through Anti-Gravity Agent Manager as the primary CEO interface. The execution machinery (dispatch.sh, execute.sh, workspace scripts) is already built — this phase connects it to the Gemini orchestrator running in Agent Manager.

**In scope:** Gemini skill/agent restructuring, Agent Manager context loading, inbox surfacing, workspace routing integration.
**Out of scope:** New execution features, Claude Code changes, additional trust mechanics.

</domain>

<decisions>
## Implementation Decisions

### Skill Structure (Hybrid Approach)

**Core orchestration in agents.md (always loaded):**
- Intent classification (dispatch/status/decision/correction/conversation)
- Workspace awareness (registry, current workspace, resolution via frecency)
- Trust/guardrails summary (approval requirements, audit expectations)
- Index pointing to script locations for retrieval

**Explicit commands as skills (user-triggered):**
- `/status` — Show dashboard, aggregate metrics
- `/briefing` — Generate daily briefing
- `/approve N` — Process approval for item N
- `/dispatch "intent"` — Explicit dispatch trigger
- Other explicit CEO directives

**Rationale:** Research (Vercel study) shows agents.md outperforms skills for passive context (56% skill non-invocation rate). Hybrid approach puts core orchestration behavior in system prompt while keeping explicit workflows as skills.

### Terminal Dispatch Mechanism

**Existing chain (no changes needed):**
1. Gemini calls `scripts/orchestrator/dispatch.sh`
2. dispatch.sh calls `scripts/worker/execute.sh --issue N`
3. execute.sh calls `claude -p "$PROMPT" --allowedTools "..."`

**Gemini invocation pattern:**
```bash
# Single dispatch
scripts/orchestrator/dispatch.sh --issue 42

# Dependency-aware dispatch
scripts/orchestrator/dispatch.sh --with-dependencies

# Status check
scripts/orchestrator/dispatch.sh --status
```

**Key insight:** The CLI machinery is complete. Phase 12 wires Gemini in Agent Manager to invoke it.

### Results to Inbox

**Three-tier result flow:**
1. **Agent Manager Inbox view** — Gemini reads `.worker/inbox/` to surface pending items
2. **Workspace conversations** — Claude workers reply in their normal conversation flow
3. **Artifacts panel** — Gemini uses artifacts to show plans before dispatching to Claude

**Inbox checking behavior:**
- Check inbox on conversation start (proactive)
- Check inbox on explicit request ("status", "check inbox")
- Do NOT poll between turns (too noisy)

**Inbox format:** Existing `.worker/inbox/` files continue as-is. Gemini parses them and surfaces in conversation.

### Workspace Context Switching

**Resolution mechanism:** Use existing frecency-based workspace resolution (Phase 9)
```bash
scripts/workspace/workspace-resolve.sh "project-name"
```

**Context persistence:** Conversation is scoped to a workspace (visible in Agent Manager sidebar). Workspace context persists across messages within a conversation.

**Cross-workspace dispatch:** When CEO says "do X in Project Y", Gemini:
1. Resolves "Project Y" via frecency/alias matching
2. Checks workspace health (Phase 8)
3. Validates trust ceiling (Phase 11)
4. Requests approval if cross-workspace (Phase 11)
5. Dispatches via appropriate workspace scripts

### Claude's Discretion

- Exact agents.md formatting and section organization
- Skill file naming conventions within .gemini/skills/
- Error message formatting in Agent Manager
- Retry/fallback logic for terminal execution failures
- Cache TTL for inbox status aggregation

</decisions>

<specifics>
## Specific Ideas

- "Wake up, brew coffee, check the inbox" — Agent Manager Inbox is the first thing CEO sees
- Gemini shows plan in Artifacts panel before dispatching (confirmation gate)
- Conversation per workspace means context doesn't leak between projects
- Existing scripts are the backend — Gemini is the frontend adapter
- Research finding: "prefer retrieval reasoning over pre-training reasoning" instruction in agents.md

</specifics>

<deferred>
## Deferred Ideas

- Push notifications from Agent Manager when workers complete (requires Agent Manager capability)
- Voice briefing generation
- Multi-CEO support and delegation through Agent Manager
- Historical analytics dashboard in Artifacts

</deferred>

---

*Phase: 12-anti-gravity-integration*
*Context gathered: 2026-01-31*

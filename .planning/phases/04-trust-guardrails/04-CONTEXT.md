# Phase 4: Trust Guardrails - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Hook-based trust enforcement that prevents destructive operations and maintains audit trail. Pre-hooks block dangerous commands before execution. Post-hooks validate outputs and log actions. Agent manifests define scope boundaries enforced at execution time.

</domain>

<decisions>
## Implementation Decisions

### Pre-hook Blocking

- Configurable pattern list with sensible defaults (not hardcoded static list)
- Patterns defined in YAML: `.claude/trust-guardrails.yaml` at project level
- Hierarchical configuration: hardcoded floor → agency (~/.claude) → project → agent manifest
- Agents can only tighten restrictions, never loosen parent rules
- Severity levels: critical, high, medium, low
- Graduated response based on severity + trust level:
  - Below threshold: hard block, no retry
  - At threshold: confirmation gate with 30s timeout
  - Above threshold: audit-only (log and allow)

**Hardcoded safety floor (non-overridable):**
- Minimal list (~10-15 patterns) of catastrophic-only commands
- Examples: rm -rf /, mkfs., dd of=/dev, curl|bash, git push --force main
- No override mechanism — even Level 4 + human approval cannot bypass

### Scope Enforcement

- Multi-dimensional scope: paths (read/write/execute), commands, git, network, resources
- Default deny-all — manifest grants permissions explicitly
- Validation chain: safety floor → path scope → command scope → git scope → network scope → trust level → resources
- Fail-closed: if validation can't determine scope, block it
- Prototype-based inheritance with modifiers:
  - `extend`: add to parent's allows
  - `restrict`: remove from inherited allows
  - `override`: replace (only for non-security fields like resources)
  - Deny lists can only be extended, never restricted

**Scope violation feedback:**
- Structured response with violation type, rule source, reason
- Actionable alternatives (delegate to capable agent, request escalation)
- Clear escalation paths when available

### Audit Logging

- Three-tier logging: audit (immutable), operational (standard), debug (ephemeral)
- Audit tier: always captured, append-only, chained checksums for tamper detection
- Local-first storage: `.planning/logs/` with structured hierarchy
- Retention: audit forever, operational 90 days, debug 7 days
- Git tracking: audit and violations always committed, debug in .gitignore

**Audit entry fields:**
- id, timestamp, agent, session, trust_level
- action (type, target, outcome)
- validation results (which checks passed/failed)
- checksum + previous_checksum for chain integrity

**Query tools:**
- CLI-first: standard grep/jq for ad-hoc, `claude-audit` helper for analysis
- Common commands: list, violations, explain, timeline, scope-report, trust-report
- Machine-readable output (JSON, table) for tooling integration
- Optional git tag anchoring for team environments

### Violation Handling

- Weighted violation scoring with decay: points accumulate, decay with clean actions
- Severity weights: safety_floor=100 (instant demote), scope_write=15, scope_read=5, etc.
- Thresholds: warning (20), probation (40), demotion (60)
- Decay rate: 5 points per clean action

**Trust impact by violation type:**
- Critical (safety floor): immediate halt, full context capture, mandatory human review
- High (repeated scope): points toward demotion, probation mode
- Medium (single scope): warning, tracked
- Low (soft limits): logged only, auto-decay

**Retry policy by violation type:**
- Safety floor: never retry, no exceptions
- Scope violation: no retry — must delegate or request manifest change
- Trust insufficient: retry allowed after human approval (one-time token)
- Resource limit: retry allowed with reduced scope (must be smaller)
- Rate limit: retry after delay (exponential backoff)

**Critical violation response:**
- Immediate halt, full context snapshot (incident file)
- Agent suspended pending human review
- Tiered severity: catastrophic (halt all agents), severe (halt this agent), serious (require acknowledgment)
- Resolution workflow via `claude-audit incident` commands

**Pattern learning:**
- Detect recurring violations, scope mismatches, workflow friction
- Surface patterns to humans with suggestions — never auto-modify rules
- Learning report: weekly analysis of violation patterns
- Human approval required for any rule changes

### Claude's Discretion

- Exact pattern matching implementation (regex engine, escaping rules)
- Validation chain performance optimization
- Log rotation and compression timing
- Specific CLI tool output formatting
- Internal data structures and caching strategies

</decisions>

<specifics>
## Specific Ideas

- "Trust is earned, never assumed" — start from zero, advance through demonstrated competence
- Guardrails should feel like Git hooks — enforcement at execution boundaries, not runtime monitoring
- Violations should tell the agent exactly what failed, why, and what options exist — not just "denied"
- Safety floor hits are treated as potential security incidents, not routine violations
- Pattern detection observes and recommends; humans decide on rule changes

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-trust-guardrails*
*Context gathered: 2026-01-27*

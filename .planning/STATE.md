# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-29)

**Core value:** Complete loop where CEO dispatches intent, orchestrator routes, Claude executes, results land in GitHub with status reporting back — now across multiple repos.
**Current focus:** Phase 10 - Portfolio Visibility

## Current Position

Phase: 10 of 12 (Portfolio Visibility)
Plan: 2 of 4 in current phase
Status: In progress
Last activity: 2026-01-30 — Completed 10-02-PLAN.md

Progress: [################....] 69% (44 of 49 plans complete)

## Milestone History

| Version | Name | Phases | Plans | Shipped |
|---------|------|--------|-------|---------|
| v1.0 | MVP | 1-7 | 36 | 2026-01-29 |
| v1.1 | Multi-Workspace | 8-12 | 13 (planned) | In progress |

See `.planning/MILESTONES.md` for full details.

## Performance Metrics

**v1.0 Velocity:**
- Total plans completed: 36
- 7 phases, ~150 tasks
- ~41,725 lines shipped

**v1.1:**
- Plans completed: 8
- Tasks completed: 16
- Lines shipped: ~3,182

## Accumulated Context

### Key Decisions

All decisions are logged in PROJECT.md Key Decisions table.
Summary of major decisions from v1.0:

- GitHub as coordination layer (auditable, human-readable)
- Hook-based trust enforcement (boundaries, not runtime)
- Label-based state machine (survives crashes)
- Exit-and-resume for approvals (no polling)
- Hash-chained audit trail (SHA-256)

**v1.1 decisions (08-01):**
- Git plumbing over porcelain for .gitmodules parsing (stable API)
- Case-insensitive alias matching using ${var,,} expansion
- Resolution order: exact dir > submodule suffix > alias

**v1.1 decisions (08-02):**
- Three-tier status (GREEN/YELLOW/RED) for health checks
- Git plumbing commands for health checks (stable API)
- Basic trust ledger validation (headers only, not full parsing)

**v1.1 decisions (08-03):**
- Trust ceiling inheritance from .worker/config.json guardrails.default_trust_level
- Template placeholder syntax: {{PLACEHOLDER}} for sed compatibility
- Function export pattern for bash scripts (source then call)
- Scaffold mode for adding structure to existing directories

**v1.1 decisions (08-04):**
- set -euo pipefail placement: inside direct-execution block prevents parent shell propagation
- Standardized if [[ ${BASH_SOURCE[0]} == $0 ]] pattern (not (return 0) || pattern)

**v1.1 decisions (09-01):**
- Time-decay frecency weights: <5d=100, 5-14d=70, 15-31d=50, 32-89d=30, 90+d=10
- Fuzzy threshold of 3 edit distance for workspace suggestions
- JSONL format for frecency events (append-only, line-by-line parsing)
- Case-insensitive matching for fuzzy suggestions

**v1.1 decisions (09-02):**
- Source order matters: fuzzy-match.sh sourced first to avoid SCRIPT_DIR overwrite
- Non-interactive mode fails on RED health (cannot prompt for confirmation)
- Trust ceiling from .worker/config.json guardrails.default_trust_level, default 2
- Event ID format: workspace-dispatch-{epoch_ns}-{pid} for uniqueness

**v1.1 decisions (10-01):**
- 5-minute cache for portfolio status (balances freshness with performance)
- 3-day threshold for workspace staleness (promotes to YELLOW health)
- Project field optional in inbox metadata (backward compatibility)

**v1.1 decisions (10-02):**
- ANSI color codes with plain text fallback (tput colors detection)
- Collapsible Needs Attention section (omit when empty)
- Frecency display mapping to human-readable activity levels (Active/Recent/Idle/New)

### Research Context

Research completed (see .planning/research/SUMMARY.md):
- Anti-Gravity Agent Manager provides unified inbox and dispatch
- Isolation before execution (critical for pitfall avoidance)
- Local dispatch first, remote dispatch later (validate patterns locally)
- Per-workspace trust ledgers required (prevent trust boundary leakage)

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-01-30
Stopped at: Completed 10-02-PLAN.md (portfolio dashboard rendering)
Resume file: None (continue with 10-03)

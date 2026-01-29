---
phase: "08"
plan: "02"
subsystem: workspace
tags: [health-check, validation, dispatch-gate]
requires: ["08-01"]
provides: [workspace-validation, workspace-health-check, dispatch-readiness]
affects: ["08-03", "09"]
tech-stack:
  added: []
  patterns: [color-coded-status, git-plumbing-commands]
key-files:
  created:
    - scripts/workspace/workspace-validate.sh
    - scripts/workspace/workspace-health.sh
  modified:
    - scripts/workspace/README.md
decisions:
  - id: "08-02-01"
    choice: "Git plumbing for health checks"
    reason: "Stable API vs porcelain commands"
    alternatives: ["git status parsing"]
  - id: "08-02-02"
    choice: "Three-tier status (GREEN/YELLOW/RED)"
    reason: "Clear actionable signals for dispatch decisions"
    alternatives: ["binary pass/fail", "numeric scores"]
metrics:
  duration: "~11 minutes"
  completed: "2026-01-29"
---

# Phase 8 Plan 02: Workspace Health Checking Summary

**One-liner:** Workspace validation and health checking with color-coded status (GREEN/YELLOW/RED) for dispatch decisions.

## What Was Built

### 1. workspace-validate.sh
Structure validation script that checks required workspace components.

**Validation Categories:**
- **REQUIRED (causes INVALID):**
  - Valid git repository
  - `.planning/trust-ledger.md` exists
  - Trust ledger has basic required headers

- **OPTIONAL (warnings only):**
  - `.claude/` directory

**Exported Function:**
```bash
validate_workspace_structure <path>
# Returns: 0 (valid) or 1 (invalid)
# Output: Validation results to stdout, errors to stderr
```

### 2. workspace-health.sh
Comprehensive health checking with three-tier status system.

**Health Check Stages:**

| Stage | Check | RED | YELLOW |
|-------|-------|-----|--------|
| Git State | Repository | Not a git repo | - |
| Git State | HEAD | - | Detached HEAD |
| Git State | Changes | - | Uncommitted changes |
| Git State | Untracked | - | Untracked source files |
| Structure | .planning/ | Missing | - |
| Structure | trust-ledger | Missing | - |
| Structure | .claude/ | - | Missing |
| Ledger | Format | - | Missing headers |

**Status Meanings:**
- **GREEN** - Healthy, ready for dispatch
- **YELLOW** - Warnings present, can proceed with caution
- **RED** - Blocking issues, dispatch blocked

**Exported Functions:**
```bash
check_workspace_health <path>
# Sets: HEALTH_STATUS, HEALTH_ISSUES[]

check_all_workspaces
# Returns: 0 (all OK/WARN) or 1 (any RED)

print_workspace_health <path>
# Outputs: Detailed health report
```

### Output Formats

**Single Workspace:**
```
Workspace: project-name
Path: /path/to/workspace
Status: YELLOW

Issues:
  - Uncommitted changes present
  - Missing .claude/ directory (optional)
```

**All Workspaces (table):**
```
Workspace Health Status
=======================

[OK]   project-a
[WARN] project-b:                      Uncommitted changes present
[ERR]  project-c:                      Missing trust ledger

Some workspaces have blocking issues (RED status).
```

## Technical Decisions

### Git Plumbing Commands
Used git plumbing commands instead of porcelain for stability:
- `git rev-parse --git-dir` - Check if git repo
- `git rev-parse --abbrev-ref HEAD` - Check for detached HEAD
- `git diff-index --quiet HEAD` - Check for uncommitted changes
- `git ls-files --others --exclude-standard` - Check untracked files

### Three-Tier Status
Chose GREEN/YELLOW/RED over binary pass/fail because:
- YELLOW allows informed proceed-with-caution decisions
- RED provides clear dispatch blocking signal
- GREEN confirms full health

### Trust Ledger Validation
Basic format validation only (check for required headers), not full markdown parsing:
- More resilient to format variations
- Catches missing required sections
- Avoids brittleness of full parsing

## Integration Points

| Script | Sources | Provides |
|--------|---------|----------|
| workspace-health.sh | workspace-list.sh | check_all_workspaces() |
| workspace-health.sh | workspace-resolve.sh | Name-to-path resolution |
| workspace-health.sh | workspace-validate.sh | Structure checks |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| b65f5aa | feat | Add workspace structure validation script |
| 928349e | feat | Add workspace health check script |

## Deviations from Plan

None - plan executed exactly as written.

## Files Changed

| File | Lines | Change |
|------|-------|--------|
| scripts/workspace/workspace-validate.sh | +119 | Created |
| scripts/workspace/workspace-health.sh | +232 | Created |
| scripts/workspace/README.md | +108 | Updated |

## Next Phase Readiness

Ready for Plan 08-03 (Dispatch Integration):
- Health check provides dispatch gate
- Status system ready for routing decisions
- Integration functions exported and documented

**Prerequisites satisfied:**
- [x] CEO can check health status of all workspaces
- [x] Unhealthy workspaces show clear explanation
- [x] RED/YELLOW/GREEN status distinction
- [x] Structure validation identifies missing files

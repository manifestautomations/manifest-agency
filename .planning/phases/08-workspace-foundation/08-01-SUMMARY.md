---
phase: 08
plan: 01
title: Workspace Discovery and Name Resolution
subsystem: workspace-management
tags: [bash, git-submodules, workspace-registry, name-resolution]

# What this plan provides for future phases
provides:
  - workspace-list-script
  - workspace-resolve-script
  - workspaces-config-section

# What this plan requires from previous phases
requires:
  - worker-config-json  # Phase 1 foundation

# What this plan affects (future phases may need to adapt)
affects:
  - 08-02  # Workspace health checks will use discovery
  - 08-03  # Bootstrap will use resolution
  - 09-01  # Dispatch routing uses workspace resolution

# Technology tracking
tech-stack:
  added:
    - git-config-plumbing  # For stable .gitmodules parsing
  patterns:
    - source-able-functions  # Scripts export functions for sourcing
    - case-insensitive-bash  # ${var,,} parameter expansion

# Files created or modified
key-files:
  created:
    - scripts/workspace/workspace-list.sh
    - scripts/workspace/workspace-resolve.sh
    - scripts/workspace/README.md
  modified:
    - .worker/config.json  # Added workspaces section

# Key decisions made
decisions:
  - id: workspace-discovery-source
    choice: "git config --file .gitmodules (plumbing command)"
    rationale: "Stable API unlike porcelain git submodule status"
  - id: alias-case-sensitivity
    choice: "Case-insensitive matching using ${var,,}"
    rationale: "User-friendly, avoids dispatch failures on capitalization"
  - id: resolution-order
    choice: "Exact dir > submodule suffix > alias"
    rationale: "Most specific match first, aliases as convenience layer"

# Metrics
metrics:
  duration: "10 minutes"
  completed: "2026-01-29"
---

# Phase 8 Plan 1: Workspace Discovery and Name Resolution Summary

**One-liner:** Git submodule discovery and case-insensitive name resolution via bash scripts

## What Was Built

Created workspace discovery and name resolution foundation:

1. **workspace-list.sh** - Discovers workspaces from .gitmodules using git plumbing commands
   - Human-readable table output by default
   - JSON output with `--porcelain` flag
   - Reports initialization status (has .git or not)
   - Exports `list_workspaces()` function for sourcing

2. **workspace-resolve.sh** - Resolves workspace names/aliases to filesystem paths
   - Resolution order: exact directory, submodule suffix, then aliases
   - Case-insensitive alias matching using bash `${var,,}` expansion
   - Helpful error messages listing valid workspaces on failure
   - Exports `resolve_workspace()` function for sourcing

3. **Config extension** - Added `workspaces` section to `.worker/config.json`
   - `aliases` array for shorthand workspace names
   - `projects_dir` setting (defaults to "projects")

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 3cd4eaf | feat | Add workspace discovery from git submodules |
| 09250a3 | feat | Add workspace name resolution with alias support |

## Implementation Details

### Key Design Decisions

**Git Plumbing over Porcelain:** Used `git config --file .gitmodules --get-regexp` instead of `git submodule status`. Plumbing commands have stable output format across git versions.

**Source-able Functions:** Both scripts can be sourced by other scripts to reuse the core functions (`list_workspaces`, `resolve_workspace`). This enables composition in Phase 9 dispatch scripts.

**Case-Insensitive Matching:** Aliases use bash 4+ parameter expansion `${var,,}` for lowercase comparison. Prevents dispatch failures from capitalization typos.

### Architecture

```
.gitmodules (source of truth)
      |
      v
workspace-list.sh --> Human/JSON output
      |
      v
workspace-resolve.sh --> Absolute path or error
      ^
      |
.worker/config.json (aliases)
```

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

**08-02 (Workspace Health):** Can use `list_workspaces --porcelain` to iterate workspaces and `resolve_workspace` to get paths for health checking.

**08-03 (Workspace Bootstrap):** Can use `resolve_workspace` to validate if a workspace already exists before bootstrapping.

**Phase 9 (Dispatch):** Foundation complete for routing dispatch to correct workspace path.

## Files

### Created
- `scripts/workspace/workspace-list.sh` (100 lines)
- `scripts/workspace/workspace-resolve.sh` (130 lines)
- `scripts/workspace/README.md` (130 lines)

### Modified
- `.worker/config.json` (+5 lines: workspaces section)

## Test Evidence

```bash
# Workspace listing (empty state)
$ source scripts/workspace/workspace-list.sh && list_workspaces
No workspaces registered (no submodules in .gitmodules)

# Porcelain output
$ source scripts/workspace/workspace-list.sh && list_workspaces --porcelain
[]

# Name resolution error case
$ source scripts/workspace/workspace-resolve.sh && resolve_workspace invalid
Workspace 'invalid' not found.
Valid workspaces:
# (empty because no projects yet)

# Config validation
$ jq '.workspaces' .worker/config.json
{
  "aliases": [],
  "projects_dir": "projects"
}
```

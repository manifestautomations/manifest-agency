# Cross-Workspace Dispatch Scripts

Route work to specific workspaces by name with health gating and intelligent defaults.

Part of cross-workspace dispatch (Phase 9).

## Scripts

### dispatch-to-workspace.sh

Main dispatch routing script for targeting workspaces by name.

**Exported Functions:**

- `dispatch_to_workspace <workspace> <task_description> [parent_agent]` - Main dispatch function
- `get_target_workspace [explicit_target]` - Intelligent target selection with frecency fallback

**Usage:**

```bash
# Direct execution
./scripts/dispatch/dispatch-to-workspace.sh "project-name" "Run tests"

# Sourced usage
source scripts/dispatch/dispatch-to-workspace.sh
dispatch_to_workspace "project-name" "Run tests" "ceo"

# With frecency default (interactive)
source scripts/dispatch/dispatch-to-workspace.sh
target=$(get_target_workspace "")  # Prompts with most frequent workspace
dispatch_to_workspace "$target" "Run tests"
```

**Return Codes:**

| Code | Meaning |
|------|---------|
| 0 | Dispatch successful |
| 1 | Dispatch failed (workspace not found, RED health declined, jq missing) |

**Environment:**

- Requires `jq` for JSON parsing
- Requires bash 4+ for associative arrays

### fuzzy-match.sh

Fuzzy matching for workspace name suggestions using Levenshtein distance.

**Exported Functions:**

- `levenshtein <str1> <str2>` - Calculate edit distance between two strings
- `suggest_workspace <input>` - Suggest workspaces matching input (typo tolerance)

**Usage:**

```bash
# Direct execution
./scripts/dispatch/fuzzy-match.sh levenshtein "test" "tset"
# Output: 2

./scripts/dispatch/fuzzy-match.sh suggest "my-projct"
# Output: my-project (if within threshold)

# Sourced usage
source scripts/dispatch/fuzzy-match.sh
distance=$(levenshtein "hello" "helo")  # Returns: 1
suggest_workspace "projec"              # Returns matching workspaces
```

**Threshold Configuration:**

The `FUZZY_THRESHOLD` variable controls maximum edit distance for suggestions (default: 3).

This threshold catches common typos:
- Missing letter: `my-projct` -> `my-project` (distance 1)
- Transposition: `tset` -> `test` (distance 2)
- Adjacent key: `my-oroject` -> `my-project` (distance 1)

## Dispatch Event Format

Events are logged to `.worker/dispatch/dispatch.jsonl` in JSONL format (one JSON object per line).

**Event Schema:**

```json
{
  "timestamp": "2026-01-30T12:00:00Z",
  "event_type": "workspace_dispatch",
  "event_id": "workspace-dispatch-1234567890-12345",
  "data": {
    "workspace_id": "my-project",
    "workspace_path": "/absolute/path/to/my-project",
    "parent_agent": "ceo",
    "trust_ceiling": 2,
    "task_description": "Run all tests and report failures",
    "health_status": "GREEN"
  }
}
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO8601 | UTC timestamp of dispatch event |
| `event_type` | string | Always `"workspace_dispatch"` for these events |
| `event_id` | string | Unique identifier: `workspace-dispatch-{epoch_ns}-{pid}` |
| `data.workspace_id` | string | Basename of workspace path |
| `data.workspace_path` | string | Absolute filesystem path |
| `data.parent_agent` | string | Dispatching agent ID (default: `"ceo"`) |
| `data.trust_ceiling` | integer | Maximum trust level for dispatched work |
| `data.task_description` | string | Task description as provided |
| `data.health_status` | string | Workspace health at dispatch time |

## Health Gating

Workspace health is checked before dispatch to prevent routing work to broken workspaces.

**Status Levels:**

| Status | Behavior | User Action |
|--------|----------|-------------|
| GREEN | Proceeds without prompt | None required |
| YELLOW | Warning shown, proceeds anyway | Acknowledge warning |
| RED | Error shown, requires confirmation | Must explicitly confirm (y/N prompt) |

**Non-Interactive Mode:**

In non-interactive mode (piped input or CI):
- GREEN/YELLOW: proceeds normally
- RED: fails immediately (cannot prompt for confirmation)

**Health Checks Performed:**

- Git repository state (initialized, not detached HEAD)
- Uncommitted changes
- .planning/ directory exists
- trust-ledger.md exists and has required sections
- .claude/ directory exists (optional, YELLOW if missing)

## Frecency Defaults

When no target workspace is specified, the system can suggest the most frequently/recently used workspace.

**How Frecency Works:**

Frecency = frequency * recency. Combines how often you use a workspace with how recently you used it.

Access events are logged to `.worker/dispatch/frecency.jsonl`:

```json
{"timestamp":"2026-01-30T12:00:00Z","workspace_id":"my-project","event":"access"}
```

**Time-Decay Weights:**

| Age | Weight |
|-----|--------|
| < 5 days | 100 |
| 5-14 days | 70 |
| 15-31 days | 50 |
| 32-89 days | 30 |
| 90+ days | 10 |

**When get_target_workspace Uses Frecency:**

1. Called with no explicit target
2. Ranks all workspaces by frecency score
3. Prompts: "No target specified. Most frequent: <name>. Use this? (Y/n)"
4. Returns selected workspace or empty if declined

**How to Reset Frecency:**

Delete the frecency log to reset all scores:

```bash
rm .worker/dispatch/frecency.jsonl
```

## Dependencies

**Required Scripts (Phase 8):**

- `scripts/workspace/workspace-resolve.sh` - Workspace name resolution
- `scripts/workspace/workspace-health.sh` - Workspace health checks
- `scripts/workspace/workspace-frecency.sh` - Frecency tracking

**Required Tools:**

- `jq` - JSON parsing (install: `brew install jq` or `apt-get install jq`)
- `bash` 4+ - For associative arrays in Levenshtein algorithm
- `git` - For workspace health checks

**Optional Tools:**

- GNU `date` with nanosecond support - For more precise event IDs (falls back to seconds + random)
